#!/bin/bash
set -e

CLIENT_NAME=$1
if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client-name>"
    exit 1
fi

cd /etc/openvpn/easy-rsa

# Generate client certificate
./easyrsa --batch build-client-full "$CLIENT_NAME" nopass

# Get the Elastic IP for OpenVPN connection
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Get Elastic IP attached to this instance
echo "Getting Elastic IP for instance..."
ELASTIC_IP=$(aws ec2 describe-addresses \
    --filters "Name=instance-id,Values=$INSTANCE_ID" \
    --region ${aws_region} \
    --query 'Addresses[0].PublicIp' \
    --output text 2>/dev/null || echo "")

# Fallback to public IP if no Elastic IP found
if [ -z "$ELASTIC_IP" ] || [ "$ELASTIC_IP" = "None" ] || [ "$ELASTIC_IP" = "null" ]; then
    echo "Warning: No Elastic IP found, using primary public IP"
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    ELASTIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4)
fi

echo "Using public IP for OpenVPN: $ELASTIC_IP"

# Create client configuration file
cat > /tmp/$CLIENT_NAME.ovpn <<EOF
client
dev tun
proto ${openvpn_protocol}
remote $ELASTIC_IP ${openvpn_port}
%{ if enable_openvpn_tcp_fallback ~}
remote $ELASTIC_IP 443 tcp
%{ endif ~}
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
cipher ${openvpn_cipher}
auth ${openvpn_auth}
%{ if openvpn_compress ~}
compress lz4-v2
push "compress lz4-v2"
%{ endif ~}
key-direction 1
remote-cert-tls server
verb 3
<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/$CLIENT_NAME.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/$CLIENT_NAME.key)
</key>
<tls-auth>
$(cat /etc/openvpn/server/ta.key)
</tls-auth>
EOF

# Upload to S3
if [ ! -z "${s3_bucket_name}" ]; then
    aws s3 cp /tmp/$CLIENT_NAME.ovpn s3://${s3_bucket_name}/clients/$CLIENT_NAME.ovpn --region ${aws_region}
    echo "Client configuration uploaded to s3://${s3_bucket_name}/clients/$CLIENT_NAME.ovpn"
    
    # Clean up local file
    rm -f /tmp/$CLIENT_NAME.ovpn
    
    echo ""
    echo "Download the client configuration with:"
    echo "aws s3 cp s3://${s3_bucket_name}/clients/$CLIENT_NAME.ovpn . --region ${aws_region}"
else
    echo "Client configuration saved to /tmp/$CLIENT_NAME.ovpn"
    echo "Copy this file to your local machine and import it into your OpenVPN client."
fi

echo ""
echo "Client certificate for '$CLIENT_NAME' has been generated successfully!"