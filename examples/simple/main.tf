# examples/simple/main.tf
# Simple bastion + OpenVPN configuration example
# This module uses Amazon Linux 2023

provider "aws" {
  region = "ap-northeast-2"
}

# VPC data source (use existing VPC)
data "aws_vpc" "main" {
  id = "vpc-xxxxxxxxx" # Replace with actual VPC ID
}

# Subnet data source (use existing public subnet)
data "aws_subnet" "public" {
  id = "subnet-xxxxxxxxx" # Replace with actual public subnet ID
}

# Call bastion-openvpn module
module "bastion_openvpn" {
  source = "../../" # Module path

  # Required settings
  vpc_id    = data.aws_vpc.main.id
  subnet_id = data.aws_subnet.public.id # Single public subnet

  # Optional settings
  name          = "my-bastion-vpn"
  instance_type = "t4g.nano" # ARM64 Graviton2 processor (cost-effective)

  # Key pair for SSH access (required)
  # key_name = "my-key-pair" # Uncomment and replace with your key pair name

  # OpenVPN settings
  openvpn_client_cidrs = ["0.0.0.0/0"] # Restrict in production recommended

  # SSH access settings (bastion functionality)
  # ssh_client_cidrs = ["YOUR_IP/32"]  # Uncomment and add your IP for direct SSH access

  # CloudWatch Alarms (disabled by default)
  # Set to true if you want CloudWatch alarms
  # enable_cloudwatch_alarms = true
  # alarm_sns_topic_arn     = aws_sns_topic.alerts.arn

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}

# Outputs
output "instance_id" {
  description = "EC2 instance ID"
  value       = module.bastion_openvpn.instance_id
}

output "elastic_ip" {
  description = "Elastic IP address for stable access"
  value       = module.bastion_openvpn.elastic_ip
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = module.bastion_openvpn.ssh_connection_string
}

output "openvpn_client_command" {
  description = "Command to generate OpenVPN client configuration"
  value       = module.bastion_openvpn.generate_client_cert_command
}

output "s3_bucket_name" {
  description = "S3 bucket for OpenVPN configuration"
  value       = module.bastion_openvpn.s3_bucket_name
}

output "instance_requirements" {
  description = "Instance requirements"
  value = {
    ami_type     = "Amazon Linux 2023"
    architecture = "ARM64 only (t4g, c6g, m6g, or r6g instances)"
    purpose      = "Bastion + OpenVPN for small teams (5-10 users)"
  }
}