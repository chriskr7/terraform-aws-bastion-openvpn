#!/bin/bash
NAMESPACE="${name_prefix}/OpenVPN"
# Get IMDSv2 token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

# Number of connected clients
CLIENTS=$(echo "status 2" | nc localhost 7505 2>/dev/null | grep "^CLIENT_LIST" | wc -l)

aws cloudwatch put-metric-data \
    --region ${aws_region} \
    --namespace "$NAMESPACE" \
    --metric-name OpenVPNConnections \
    --value "$CLIENTS" \
    --dimensions InstanceId="$INSTANCE_ID"