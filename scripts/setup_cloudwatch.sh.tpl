#!/bin/bash
set -ex

CW_LOG_GROUP="${cloudwatch_log_group}"
NAME_PREFIX="${name_prefix}"

if [ -z "$CW_LOG_GROUP" ]; then
    echo "CloudWatch log group not configured, skipping..."
    exit 0
fi

# CloudWatch Agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "$CW_LOG_GROUP",
            "log_stream_name": "{instance_id}/system"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "$CW_LOG_GROUP",
            "log_stream_name": "{instance_id}/user-data"
          }
%{ if enable_openvpn ~}
          ,{
            "file_path": "/var/log/openvpn/server.log",
            "log_group_name": "$CW_LOG_GROUP",
            "log_stream_name": "{instance_id}/openvpn"
          }
%{ endif ~}
        ]
      }
    }
  },
  "metrics": {
    "namespace": "$NAME_PREFIX/System",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_USAGE_IDLE",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": ["/"]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json