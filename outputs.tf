# EC2 Instance Outputs
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.bastion_openvpn.id
}

output "instance_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.bastion_openvpn.public_ip
}

output "instance_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.bastion_openvpn.private_ip
}

output "elastic_ip" {
  description = "Elastic IP address"
  value       = aws_eip.bastion_openvpn.public_ip
}

# Security Group Outputs
output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.bastion_openvpn.id
}

# IAM Outputs
output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.bastion_openvpn.arn
}

output "iam_instance_profile_name" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.bastion_openvpn.name
}

# S3 Bucket Outputs (if enabled)
output "s3_bucket_name" {
  description = "S3 bucket name for OpenVPN configuration"
  value       = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for OpenVPN configuration"
  value       = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].arn : null
}

# CloudWatch Outputs (if enabled)
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.bastion_openvpn[0].name : null
}

# OpenVPN Configuration
output "openvpn_connection_info" {
  description = "OpenVPN connection information"
  value = {
    server_ip   = aws_eip.bastion_openvpn.public_ip
    port        = var.openvpn_port
    protocol    = var.openvpn_protocol
    network     = "${var.openvpn_network}/${var.openvpn_netmask_bits}"
    dns_servers = var.openvpn_dns_servers
  }
}

# SSH Connection String
output "ssh_connection_string" {
  description = "SSH connection string for bastion access"
  value       = "ssh -i <key-file> ec2-user@${aws_eip.bastion_openvpn.public_ip}"
}

# Client Certificate Generation Command
output "generate_client_cert_command" {
  description = "Command to generate OpenVPN client certificates"
  value       = "sudo /usr/local/bin/generate-client-cert.sh <client-name>"
}

# Certificate Renewal Settings
output "certificate_renewal_settings" {
  description = "Certificate renewal configuration settings"
  value = {
    auto_renewal_enabled = var.enable_certificate_auto_renewal
    lifetime_days        = var.certificate_lifetime_days
    renewal_days_before  = var.certificate_renewal_days
  }
}