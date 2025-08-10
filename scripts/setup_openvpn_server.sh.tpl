#!/bin/bash
set -ex

# Get the primary interface (usually eth0)
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
[ -z "$PRIMARY_INTERFACE" ] && PRIMARY_INTERFACE="eth0"
echo "Using interface for OpenVPN NAT: $PRIMARY_INTERFACE"

# OpenVPN server configuration
cat > /etc/openvpn/server/server.conf <<EOF
# OpenVPN Server Configuration
port ${openvpn_port}
proto ${openvpn_protocol}
dev tun

# Certificates and keys
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0

# Network configuration
server ${openvpn_network} ${openvpn_netmask}
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# Push routes to clients
# VPC CIDR route (from environment variable if set)
$(if [ -n "$OPENVPN_VPC_CIDR" ]; then
    # Convert CIDR to IP and netmask format
    VPC_IP=$(echo "$OPENVPN_VPC_CIDR" | cut -d'/' -f1)
    VPC_BITS=$(echo "$OPENVPN_VPC_CIDR" | cut -d'/' -f2)
    
    # Convert CIDR bits to netmask
    if [ "$VPC_BITS" = "16" ]; then
        VPC_MASK="255.255.0.0"
    elif [ "$VPC_BITS" = "24" ]; then
        VPC_MASK="255.255.255.0"
    elif [ "$VPC_BITS" = "8" ]; then
        VPC_MASK="255.0.0.0"
    else
        # Default to /16 if not recognized
        VPC_MASK="255.255.0.0"
    fi
    
    echo "push \"route $VPC_IP $VPC_MASK\""
fi)
%{ for route in openvpn_push_routes ~}
push "route ${route}"
%{ endfor ~}

# Push DNS servers to clients
%{ for dns in openvpn_dns_servers ~}
push "dhcp-option DNS ${dns}"
%{ endfor ~}

# Client configuration
keepalive 10 120
cipher ${openvpn_cipher}
auth ${openvpn_auth}
%{ if openvpn_compress ~}
compress lz4-v2
push "compress lz4-v2"
%{ endif ~}

# Security
user nobody
group nobody
persist-key
persist-tun

# Logging
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3

# Management interface (for monitoring)
management localhost 7505

# Enable client-to-client communication if needed
%{ if enable_client_to_client ~}
client-to-client
%{ endif ~}

# Allow duplicate certificates if needed
%{ if allow_duplicate_cn ~}
duplicate-cn
%{ endif ~}

# TCP fallback configuration
%{ if enable_openvpn_tcp_fallback ~}
# TCP server on port 443 for fallback
# Configure this separately if needed
%{ endif ~}
EOF

# Configure TCP fallback if enabled
%{ if enable_openvpn_tcp_fallback ~}
cat > /etc/openvpn/server/server-tcp.conf <<EOF
# OpenVPN Server Configuration (TCP Fallback)
port 443
proto tcp
dev tun1

# Use same certificates
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0

# Different network for TCP
server 10.9.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp-tcp.txt

# Same push routes
%{ for route in openvpn_push_routes ~}
push "route ${route}"
%{ endfor ~}

# Same DNS servers
%{ for dns in openvpn_dns_servers ~}
push "dhcp-option DNS ${dns}"
%{ endfor ~}

# Same security settings
keepalive 10 120
cipher ${openvpn_cipher}
auth ${openvpn_auth}
%{ if openvpn_compress ~}
compress lz4-v2
push "compress lz4-v2"
%{ endif ~}
user nobody
group nobody
persist-key
persist-tun

# Logging for TCP
status /var/log/openvpn/openvpn-tcp-status.log
log-append /var/log/openvpn/openvpn-tcp.log
verb 3

# Management interface for TCP (different port)
management localhost 7506
EOF
%{ endif ~}

# Configure IP forwarding and NAT
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Setup iptables rules for NAT
iptables -t nat -A POSTROUTING -s ${openvpn_network}/${openvpn_netmask_bits} -o $PRIMARY_INTERFACE -j MASQUERADE
%{ if enable_openvpn_tcp_fallback ~}
iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o $PRIMARY_INTERFACE -j MASQUERADE
%{ endif ~}

# Allow forwarding
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -o tun+ -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
iptables-save > /etc/sysconfig/iptables

# Enable and start OpenVPN
systemctl enable openvpn-server@server
systemctl start openvpn-server@server

%{ if enable_openvpn_tcp_fallback ~}
systemctl enable openvpn-server@server-tcp
systemctl start openvpn-server@server-tcp
%{ endif ~}

echo "OpenVPN server setup complete!"