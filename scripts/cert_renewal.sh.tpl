#!/bin/bash
# OpenVPN certificate auto-renewal script

set -e

# Configuration
EASYRSA_DIR="/etc/openvpn/easy-rsa"
S3_BUCKET="${s3_bucket_name}"
DAYS_BEFORE_EXPIRY=${certificate_renewal_days}
CERT_LIFETIME_DAYS=${certificate_lifetime_days}
AWS_REGION="${aws_region}"
NAMESPACE="${cloudwatch_namespace}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/openvpn-cert-renewal.log
}

# Check certificate expiration date
check_cert_expiry() {
    local cert_file="$1"
    local cert_name="$2"
    
    if [ ! -f "$cert_file" ]; then
        log "ERROR: Certificate file not found: $cert_file"
        return 1
    fi
    
    local expiry_date
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch
    current_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    log "Certificate $cert_name: $days_left days until expiration"
    
    if [ $days_left -lt $DAYS_BEFORE_EXPIRY ]; then
        log "WARNING: Certificate $cert_name needs renewal"
        return 0
    else
        return 1
    fi
}

# Backup PKI to S3
backup_pki_to_s3() {
    local backup_date=$(date +%Y%m%d%H%M%S)
    log "Backing up PKI to S3 with timestamp: $backup_date"
    
    # Create tar archive of PKI
    tar czf "/tmp/pki-backup-$backup_date.tar.gz" -C "$EASYRSA_DIR" pki/
    
    # Upload to S3
    aws s3 cp "/tmp/pki-backup-$backup_date.tar.gz" \
        "s3://$S3_BUCKET/pki-backup/pki-backup-$backup_date.tar.gz" \
        --region "$AWS_REGION"
    
    # Clean up local backup
    rm -f "/tmp/pki-backup-$backup_date.tar.gz"
    
    # Keep only last 30 backups
    aws s3 ls "s3://$S3_BUCKET/pki-backup/" --region "$AWS_REGION" | \
        sort -r | tail -n +31 | awk '{print $4}' | \
        xargs -I {} aws s3 rm "s3://$S3_BUCKET/pki-backup/{}" --region "$AWS_REGION" 2>/dev/null || true
    
    log "PKI backup to S3 completed"
}

# Renew server certificate
renew_server_cert() {
    log "Starting server certificate renewal"
    
    cd "$EASYRSA_DIR"
    
    # Backup current certificates locally
    local backup_date=$(date +%Y%m%d%H%M%S)
    cp pki/issued/server.crt "pki/issued/server.crt.$backup_date.bak"
    cp pki/private/server.key "pki/private/server.key.$backup_date.bak"
    
    # Generate new certificate (with automatic yes confirmation)
    echo yes | ./easyrsa renew server
    
    # Copy to OpenVPN directory
    cp pki/issued/server.crt /etc/openvpn/server/
    cp pki/private/server.key /etc/openvpn/server/
    
    # Backup entire PKI to S3
    backup_pki_to_s3
    
    # Also backup individual server certificates
    aws s3 cp pki/issued/server.crt "s3://$S3_BUCKET/certs/server/server.crt" --region "$AWS_REGION"
    aws s3 cp pki/private/server.key "s3://$S3_BUCKET/certs/server/server.key" --region "$AWS_REGION"
    
    log "Server certificate renewal completed"
}

# Renew client certificate
renew_client_cert() {
    local client_name="$1"
    log "Starting client certificate renewal: $client_name"
    
    cd "$EASYRSA_DIR"
    
    # Backup current certificate
    local backup_date=$(date +%Y%m%d%H%M%S)
    cp "pki/issued/$client_name.crt" "pki/issued/$client_name.crt.$backup_date.bak"
    
    # Generate new certificate (with automatic yes confirmation)
    echo yes | ./easyrsa renew "$client_name"
    
    # Regenerate .ovpn file
    /usr/local/bin/generate-client-cert.sh "$client_name"
    
    # Backup to S3
    backup_pki_to_s3
    
    log "Client certificate renewal completed: $client_name"
}

# Send CloudWatch metric
send_metric() {
    local metric_name="$1"
    local value="$2"
    local unit="$${3:-Count}"
    
    # Get instance ID with IMDSv2
    local token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    local instance_id=$(curl -H "X-aws-ec2-metadata-token: $token" -s http://169.254.169.254/latest/meta-data/instance-id)
    
    aws cloudwatch put-metric-data \
        --namespace "$NAMESPACE" \
        --metric-name "$metric_name" \
        --value "$value" \
        --unit "$unit" \
        --dimensions InstanceId="$instance_id" \
        --region "$AWS_REGION"
}

# Main logic
main() {
    log "=== Starting certificate renewal check ==="
    
    # Check server certificate
    if check_cert_expiry "$EASYRSA_DIR/pki/issued/server.crt" "server"; then
        renew_server_cert
        
        # Restart OpenVPN service
        log "Restarting OpenVPN service after certificate renewal"
        systemctl restart openvpn-server@server
        
        # Wait for service to be ready
        sleep 5
        
        # Check service status
        if systemctl is-active --quiet openvpn-server@server; then
            log "OpenVPN service restarted successfully"
            send_metric "CertificateRenewed" 1
        else
            log "ERROR: OpenVPN service failed to restart"
            send_metric "CertificateRenewalError" 1
        fi
    fi
    
    # Check client certificates (get list from S3)
    aws s3 ls "s3://$S3_BUCKET/clients/" --region "$AWS_REGION" | grep ".ovpn" | while read -r line; do
        client_file=$(echo "$line" | awk '{print $4}')
        client_name="$${client_file%.ovpn}"
        
        if [ -f "$EASYRSA_DIR/pki/issued/$client_name.crt" ]; then
            if check_cert_expiry "$EASYRSA_DIR/pki/issued/$client_name.crt" "$client_name"; then
                renew_client_cert "$client_name"
            fi
        fi
    done
    
    # Send certificate expiration metrics
    if [ -f "$EASYRSA_DIR/pki/issued/server.crt" ]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "$EASYRSA_DIR/pki/issued/server.crt" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local server_days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        send_metric "ServerCertificateDaysRemaining" "$server_days_left" "None"
        log "Server certificate has $server_days_left days remaining"
    fi
    
    log "=== Certificate renewal check completed ==="
}

# Execute script
main