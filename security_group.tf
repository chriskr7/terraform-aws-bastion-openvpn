

# Security Group
resource "aws_security_group" "bastion_openvpn" {
  name        = var.security_group_name != "" ? var.security_group_name : "${local.name_prefix}-sg"
  description = "Security group for bastion with OpenVPN"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Purpose = "bastion-openvpn"
    }
  )

  # Add lifecycle to handle cleanup
  lifecycle {
    create_before_destroy = true
  }

}

# Security Group Rules - OpenVPN
resource "aws_security_group_rule" "openvpn_ingress" {
  type              = "ingress"
  from_port         = var.openvpn_port
  to_port           = var.openvpn_port
  protocol          = var.openvpn_protocol
  cidr_blocks       = var.openvpn_client_cidrs
  security_group_id = aws_security_group.bastion_openvpn.id
  description       = "OpenVPN access"
}

# Security Group Rules - OpenVPN TCP Backup (only when UDP is used)
resource "aws_security_group_rule" "openvpn_tcp_backup" {
  count = var.openvpn_protocol == "udp" && var.enable_openvpn_tcp_fallback ? 1 : 0

  type              = "ingress"
  from_port         = var.openvpn_port
  to_port           = var.openvpn_port
  protocol          = "tcp"
  cidr_blocks       = var.openvpn_client_cidrs
  security_group_id = aws_security_group.bastion_openvpn.id
  description       = "OpenVPN TCP fallback"
}

# Security Group Rules - SSH (from VPN clients)
resource "aws_security_group_rule" "ssh_from_vpn" {
  count = var.enable_ssh_from_vpn ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.openvpn_network}/${var.openvpn_netmask_bits}"]
  security_group_id = aws_security_group.bastion_openvpn.id
  description       = "SSH from VPN clients"
}

# Security Group Rules - SSH (bastion access from external IPs)
resource "aws_security_group_rule" "ssh_bastion_access" {
  count = length(var.ssh_client_cidrs) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_client_cidrs
  security_group_id = aws_security_group.bastion_openvpn.id
  description       = "SSH bastion access from allowed IPs"
}

# Security Group Rules - Allow all traffic from same security group (VPC internal)
resource "aws_security_group_rule" "self_reference" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.bastion_openvpn.id
  security_group_id        = aws_security_group.bastion_openvpn.id
  description              = "Allow all traffic from instances using same security group"
}

# Security Group Rules - All Outbound
resource "aws_security_group_rule" "all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_openvpn.id
  description       = "All outbound traffic"
}


# Additional Security Group Rules
resource "aws_security_group_rule" "additional_ingress" {
  for_each = { for idx, rule in var.additional_security_group_rules : idx => rule if rule.type == "ingress" }

  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  security_group_id = aws_security_group.bastion_openvpn.id
  description       = lookup(each.value, "description", null)
}
