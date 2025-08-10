#!/bin/bash
# OpenVPN installation script for Amazon Linux 2023
# This script compiles OpenVPN from source since it's not available in AL2023 repos

set -ex

echo "=== Installing OpenVPN on Amazon Linux 2023 ==="

# Install development tools and dependencies
echo "Installing build dependencies..."
dnf groupinstall -y "Development Tools"
dnf install -y \
    gcc \
    make \
    autoconf \
    automake \
    pkgconfig \
    openssl-devel \
    lzo-devel \
    pam-devel \
    systemd-devel \
    wget \
    tar

# Download and compile OpenVPN
echo "Downloading OpenVPN source..."
cd /tmp
wget https://swupdate.openvpn.org/community/releases/openvpn-2.5.9.tar.gz
tar xzf openvpn-2.5.9.tar.gz
cd openvpn-2.5.9

echo "Configuring OpenVPN..."
./configure --enable-systemd --enable-iproute2

echo "Compiling OpenVPN..."
make -j"$(nproc)"

echo "Installing OpenVPN..."
make install

# Create systemd service file
echo "Creating systemd service..."
cat > /usr/lib/systemd/system/openvpn-server@.service <<'EOF'
[Unit]
Description=OpenVPN service for %I
After=network-online.target
Wants=network-online.target
Documentation=man:openvpn(8)

[Service]
Type=notify
PrivateTmp=true
WorkingDirectory=/etc/openvpn/server
ExecStart=/usr/local/sbin/openvpn --status /run/openvpn-server/status-%i.log --status-version 2 --suppress-timestamps --config /etc/openvpn/server/%i.conf
CapabilityBoundingSet=CAP_IPC_LOCK CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SETGID CAP_SETUID CAP_SETPCAP CAP_SYS_CHROOT CAP_DAC_OVERRIDE CAP_AUDIT_WRITE
LimitNPROC=10
DeviceAllow=/dev/null rw
DeviceAllow=/dev/net/tun rw
RestartSec=5s
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Create necessary directories FIRST
echo "Creating OpenVPN directories..."
mkdir -p /etc/openvpn/server
mkdir -p /etc/openvpn/client
mkdir -p /var/log/openvpn
mkdir -p /run/openvpn-server

# Install Easy-RSA
echo "Installing Easy-RSA..."
cd /tmp
wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.7/EasyRSA-3.1.7.tgz
tar xzf EasyRSA-3.1.7.tgz
mv EasyRSA-3.1.7 /etc/openvpn/easy-rsa
chmod +x /etc/openvpn/easy-rsa/easyrsa

# Create OpenVPN user and group
groupadd -r openvpn 2>/dev/null || true
useradd -r -g openvpn -s /sbin/nologin -d /var/lib/openvpn openvpn 2>/dev/null || true

# Set permissions
chown -R openvpn:openvpn /var/log/openvpn
chown -R openvpn:openvpn /run/openvpn-server

# Create symlinks for easier access
ln -sf /usr/local/sbin/openvpn /usr/sbin/openvpn

# Reload systemd
systemctl daemon-reload

echo "OpenVPN installation completed successfully!"
echo "OpenVPN version:"
/usr/local/sbin/openvpn --version | head -1

# Clean up
rm -rf /tmp/openvpn-* /tmp/EasyRSA-* || true