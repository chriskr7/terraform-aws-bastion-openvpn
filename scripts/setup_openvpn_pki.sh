#!/bin/bash
set -ex

S3_BUCKET="$1"
AWS_REGION="$2"

# Try to download existing configuration from S3
if [ -n "$S3_BUCKET" ]; then
    aws s3 cp "s3://$S3_BUCKET/server/" /etc/openvpn/server/ --recursive --region "$AWS_REGION" || true
    aws s3 cp "s3://$S3_BUCKET/pki/" /etc/openvpn/easy-rsa/ --recursive --region "$AWS_REGION" || true
fi

# Create new configuration if not exists
if [ ! -f /etc/openvpn/server/ca.crt ]; then
    echo "=== Generating OpenVPN certificates ==="

    # Easy-RSA configuration
    # Skip copying if files already exist (installed from source)
    if [ ! -f /etc/openvpn/easy-rsa/easyrsa ]; then
        # Try to copy from package installation path (if exists)
        if [ -d /usr/share/easy-rsa/3 ]; then
            cp -r /usr/share/easy-rsa/3/* /etc/openvpn/easy-rsa/
        else
            echo "Easy-RSA already installed from source, skipping copy"
        fi
    fi

    cd /etc/openvpn/easy-rsa

    # Create vars file
    cat > vars <<EOF
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "CA"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "fck-nat-openvpn"
set_var EASYRSA_REQ_EMAIL      "admin@example.com"
set_var EASYRSA_REQ_OU         "IT"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    3650
EOF

    # Initialize PKI
    ./easyrsa --batch init-pki

    # Create CA
    ./easyrsa --batch build-ca nopass

    # Generate server certificate
    ./easyrsa --batch build-server-full server nopass

    # Generate DH parameters
    ./easyrsa --batch gen-dh

    # Generate TLS key
    openvpn --genkey --secret /etc/openvpn/server/ta.key

    # Copy certificates
    cp pki/ca.crt /etc/openvpn/server/
    cp pki/issued/server.crt /etc/openvpn/server/
    cp pki/private/server.key /etc/openvpn/server/
    cp pki/dh.pem /etc/openvpn/server/

    # Backup to S3
    if [ -n "$S3_BUCKET" ]; then
        aws s3 cp /etc/openvpn/server/ "s3://$S3_BUCKET/server/" --recursive --region "$AWS_REGION"
        aws s3 cp /etc/openvpn/easy-rsa/pki/ "s3://$S3_BUCKET/pki/" --recursive --region "$AWS_REGION"
    fi
fi