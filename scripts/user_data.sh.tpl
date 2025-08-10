#!/bin/bash
set -ex

# Log output to console and syslog
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Bastion-OpenVPN initialization ==="

# Variables from Terraform
NAME_PREFIX="${name_prefix}"
S3_BUCKET="${s3_bucket_name}"
ENABLE_OPENVPN="${enable_openvpn}"
VPC_CIDR="${vpc_cidr}"
CW_LOG_GROUP="${cloudwatch_log_group}"
AWS_REGION="${aws_region}"
OPENVPN_PORT="${openvpn_port}"
OPENVPN_PROTOCOL="${openvpn_protocol}"
OPENVPN_CIDR="${openvpn_cidr}"
OPENVPN_DNS_SERVERS="${openvpn_dns_servers}"
ELASTIC_IP="${elastic_ip}"

# Update system
dnf update -y

# Install essential packages
dnf install -y \
    amazon-cloudwatch-agent \
    aws-cli \
    cronie \
    htop \
    iptables-services \
    jq \
    nc \
    net-tools \
    python3-pip \
    tmux \
    tree \
    vim

# Install Session Manager plugin for SSH access (ARM64 only)
SSM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"
echo "Installing Session Manager Plugin (ARM64)"
dnf install -y "$SSM_URL"

# Enable IP forwarding (for VPN routing)
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure OpenVPN if enabled
if [ "$ENABLE_OPENVPN" = "true" ]; then
    echo "=== Installing OpenVPN ==="
    
    # S3 bucket is required for OpenVPN installation
    if [ -z "$S3_BUCKET" ]; then
        echo "ERROR: S3 bucket is required for OpenVPN installation"
        exit 1
    fi
    
    # Download OpenVPN installation script from S3
    echo "Downloading OpenVPN installation script from S3..."
    if ! aws s3 cp "s3://$S3_BUCKET/scripts/install_openvpn_al2023.sh" /tmp/install_openvpn_al2023.sh --region "$AWS_REGION"; then
        echo "ERROR: Failed to download install_openvpn_al2023.sh from S3 bucket: $S3_BUCKET"
        exit 1
    fi
    
    # Run the installation script
    chmod +x /tmp/install_openvpn_al2023.sh
    /tmp/install_openvpn_al2023.sh
    
    # Create OpenVPN directories (if not already created)
    mkdir -p /etc/openvpn/server
    mkdir -p /etc/openvpn/client-configs
    
    # Download and run PKI setup script
    echo "Downloading PKI setup script from S3..."
    aws s3 cp "s3://$S3_BUCKET/scripts/setup_openvpn_pki.sh" /tmp/setup_openvpn_pki.sh --region "$AWS_REGION" || {
        echo "ERROR: Failed to download setup_openvpn_pki.sh from S3"
        exit 1
    }
    chmod +x /tmp/setup_openvpn_pki.sh
    /tmp/setup_openvpn_pki.sh "$S3_BUCKET" "$AWS_REGION"
    
    # Get and save Elastic IP for client certificate generation
    echo "Getting server public IP..."
    
    # Try IMDSv2 first with timeout
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -m 2 -s 2>/dev/null || echo "")
    
    if [ -n "$TOKEN" ]; then
        echo "Using IMDSv2..."
        INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -m 2 -s http://169.254.169.254/latest/meta-data/instance-id || echo "")
        PUBLIC_IP_META=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -m 2 -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "")
    else
        echo "Using IMDSv1..."
        INSTANCE_ID=$(curl -m 2 -s http://169.254.169.254/latest/meta-data/instance-id || echo "")
        PUBLIC_IP_META=$(curl -m 2 -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "")
    fi
    
    # Try to get Elastic IP from AWS API
    PUBLIC_IP=""
    if [ -n "$INSTANCE_ID" ]; then
        echo "Checking for Elastic IP via AWS API..."
        EIP_RESULT=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=$INSTANCE_ID" --query 'Addresses[0].PublicIp' --output text --region "$AWS_REGION" 2>/dev/null || echo "")
        
        if [ -n "$EIP_RESULT" ] && [ "$EIP_RESULT" != "None" ] && [ "$EIP_RESULT" != "null" ]; then
            PUBLIC_IP="$EIP_RESULT"
            echo "Found Elastic IP: $PUBLIC_IP"
        fi
    fi
    
    # Fallback to instance public IP
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="$PUBLIC_IP_META"
        echo "Using instance public IP: $PUBLIC_IP"
    fi
    
    # Save the Elastic IP for client certificate generation script
    if [ -n "$PUBLIC_IP" ]; then
        echo "$PUBLIC_IP" > /etc/openvpn/server/.elastic_ip
        chmod 644 /etc/openvpn/server/.elastic_ip
    fi
    
    # Download and run OpenVPN server setup script
    echo "Downloading OpenVPN server setup script from S3..."
    aws s3 cp "s3://$S3_BUCKET/scripts/setup_openvpn_server.sh" /tmp/setup_openvpn_server.sh --region "$AWS_REGION" || {
        echo "ERROR: Failed to download setup_openvpn_server.sh from S3"
        exit 1
    }
    chmod +x /tmp/setup_openvpn_server.sh
    
    # Add VPC route to the server config (since it's not in the template variables)
    export OPENVPN_VPC_CIDR="$VPC_CIDR"
    /tmp/setup_openvpn_server.sh
    
    # Create log directory
    mkdir -p /var/log/openvpn
    
    # Configure iptables for VPN
    iptables -t nat -A POSTROUTING -s "$OPENVPN_CIDR" -o eth0 -j MASQUERADE
    iptables -A FORWARD -i tun0 -j ACCEPT
    iptables -A FORWARD -o tun0 -j ACCEPT
    service iptables save
    
    # Enable and start OpenVPN
    systemctl enable openvpn-server@server
    systemctl start openvpn-server@server
    
    # Download client certificate generation script from S3
    echo "Downloading client certificate generation script from S3..."
    aws s3 cp "s3://$S3_BUCKET/scripts/generate_openvpn_client.sh" /usr/local/bin/generate-client-cert.sh --region "$AWS_REGION" || {
        echo "ERROR: Failed to download generate_openvpn_client.sh from S3"
        exit 1
    }
    chmod +x /usr/local/bin/generate-client-cert.sh
    
    # Download and setup OpenVPN metrics script
    echo "Downloading OpenVPN metrics script from S3..."
    aws s3 cp "s3://$S3_BUCKET/scripts/openvpn_metrics.sh" /usr/local/bin/openvpn-metrics.sh --region "$AWS_REGION" || {
        echo "WARNING: Failed to download openvpn_metrics.sh from S3"
    }
    
    CRON_JOBS_ADDED=false
    
    if [ -f /usr/local/bin/openvpn-metrics.sh ]; then
        chmod +x /usr/local/bin/openvpn-metrics.sh
        # Add cron job for metrics collection every 5 minutes
        echo "*/5 * * * * root /usr/local/bin/openvpn-metrics.sh" >> /etc/crontab
        CRON_JOBS_ADDED=true
    fi
    
    # Download certificate renewal script if auto-renewal is enabled
    if [ "${enable_certificate_auto_renewal}" = "true" ]; then
        echo "Downloading certificate renewal script from S3..."
        aws s3 cp "s3://$S3_BUCKET/scripts/cert_renewal.sh" /usr/local/bin/cert-renewal.sh --region "$AWS_REGION" || {
            echo "WARNING: Failed to download cert_renewal.sh from S3"
        }
        
        if [ -f /usr/local/bin/cert-renewal.sh ]; then
            chmod +x /usr/local/bin/cert-renewal.sh
            # Add daily cron job for certificate renewal check
            echo "0 2 * * * root /usr/local/bin/cert-renewal.sh" >> /etc/crontab
            CRON_JOBS_ADDED=true
        fi
    fi
    
    # Enable and start cron service if any cron jobs were added
    if [ "$CRON_JOBS_ADDED" = "true" ]; then
        echo "Enabling and starting cron service..."
        systemctl enable crond
        systemctl start crond
        echo "Cron service started successfully"
    fi
fi

# Configure CloudWatch if enabled
if [ -n "$CW_LOG_GROUP" ]; then
    echo "=== Configuring CloudWatch ==="
    
    # Download and run CloudWatch setup script
    echo "Downloading CloudWatch setup script from S3..."
    aws s3 cp "s3://$S3_BUCKET/scripts/setup_cloudwatch.sh" /tmp/setup_cloudwatch.sh --region "$AWS_REGION" || {
        echo "WARNING: Failed to download setup_cloudwatch.sh from S3, skipping CloudWatch setup"
    }
    
    if [ -f /tmp/setup_cloudwatch.sh ]; then
        chmod +x /tmp/setup_cloudwatch.sh
        /tmp/setup_cloudwatch.sh
    fi
fi

# Create MOTD
cat > /etc/motd <<EOF
===============================================
       Bastion with OpenVPN Server
===============================================
Instance: $(hostname)
Region: $AWS_REGION
VPC CIDR: $VPC_CIDR

OpenVPN Status: $(systemctl is-active openvpn-server@server)
OpenVPN Port: $OPENVPN_PORT/$OPENVPN_PROTOCOL

To generate a client certificate:
  sudo /usr/local/bin/generate-client-cert.sh <client-name>

===============================================
EOF

echo "=== Bastion-OpenVPN initialization complete ==="