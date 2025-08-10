# examples/complete/main.tf
# Complete bastion + OpenVPN configuration example
# This module uses Amazon Linux 2023 and single EC2 instance

provider "aws" {
  region = var.aws_region
}

# Create VPC (or use existing)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.11.0/24"]

  enable_nat_gateway = true # Using AWS NAT Gateway for NAT
  enable_vpn_gateway = false

  tags = var.common_tags
}

# SNS topic (for alarms)
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# bastion-openvpn module
module "bastion_openvpn" {
  source = "../../"

  # Basic settings
  name      = var.project_name
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0] # Single public subnet

  # EC2 settings (Amazon Linux 2023)
  instance_type              = var.instance_type
  key_name                   = var.key_name
  enable_detailed_monitoring = true

  # EBS settings
  root_volume_size      = 30
  root_volume_type      = "gp3"
  root_volume_encrypted = true

  # OpenVPN settings
  openvpn_port                = 1194
  openvpn_protocol            = "udp"
  enable_openvpn_tcp_fallback = true
  openvpn_network             = "10.8.0.0"
  openvpn_netmask             = "255.255.255.0"
  openvpn_netmask_bits        = 24
  openvpn_dns_servers         = ["8.8.8.8", "8.8.4.4"]
  openvpn_client_cidrs        = var.allowed_client_cidrs
  openvpn_push_routes         = ["10.0.0.0/16"] # Push VPC CIDR to clients
  openvpn_cipher              = "AES-256-GCM"
  openvpn_auth                = "SHA512"
  openvpn_compress            = true
  enable_ssh_from_vpn         = true

  # SSH access settings (bastion functionality)
  ssh_client_cidrs = var.allowed_client_cidrs # Allow direct SSH from same IPs as VPN

  # S3 settings
  create_s3_bucket = true

  # IAM settings
  additional_iam_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  additional_iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      Resource = ["*"]
    }
  ]

  # Additional security group rules
  additional_security_group_rules = [
    {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "HTTPS from VPC"
    }
  ]

  # CloudWatch settings
  enable_cloudwatch_logs             = true
  cloudwatch_log_retention_days      = 90
  enable_cloudwatch_alarms           = true
  alarm_sns_topic_arn                = aws_sns_topic.alerts.arn
  openvpn_connection_alarm_threshold = 10 # Alert if more than 10 connections

  # Certificate renewal settings
  enable_certificate_auto_renewal = true
  certificate_lifetime_days       = 365
  certificate_renewal_days        = 30

  # Custom user data script
  custom_user_data = <<-EOF
    # Additional security settings
    echo "AllowUsers ec2-user" >> /etc/ssh/sshd_config
    systemctl restart sshd

    # Install additional monitoring tools (Amazon Linux 2023)
    dnf install -y htop iotop
  EOF

  tags = merge(
    var.common_tags,
    {
      Module = "bastion-openvpn"
    }
  )
}

# CloudWatch dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", {
              stat = "Average"
              dimensions = {
                InstanceId = module.bastion_openvpn.instance_id
              }
            }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "CPU Utilization"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${var.project_name}/OpenVPN", "OpenVPNConnections", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "OpenVPN Connections"
        }
      }
    ]
  })
}

# Variables
variable "aws_region" {
  default = "ap-northeast-2"
}

variable "project_name" {
  default = "my-infra"
}

variable "instance_type" {
  description = "EC2 instance type (ARM64 recommended)"
  default     = "t4g.nano" # ARM64 Graviton2 processor for cost-effectiveness (5-10 users)
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "allowed_client_cidrs" {
  description = "Allowed client IPs for OpenVPN and SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict to specific IPs in production
}

variable "alert_email" {
  description = "Email for alarm notifications"
  type        = string
}

variable "common_tags" {
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Outputs
output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = module.bastion_openvpn.instance_id
}

output "bastion_elastic_ip" {
  description = "Bastion instance Elastic IP"
  value       = module.bastion_openvpn.elastic_ip
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = module.bastion_openvpn.ssh_connection_string
}

output "openvpn_connection_info" {
  description = "OpenVPN connection information"
  value = {
    server_ip            = module.bastion_openvpn.elastic_ip
    connection_info      = module.bastion_openvpn.openvpn_connection_info
    client_config_script = module.bastion_openvpn.generate_client_cert_command
  }
}

output "s3_bucket" {
  description = "S3 bucket for OpenVPN configuration"
  value       = module.bastion_openvpn.s3_bucket_name
}

output "monitoring" {
  description = "Monitoring information"
  value = {
    dashboard_url = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
    log_group     = module.bastion_openvpn.cloudwatch_log_group_name
  }
}

output "certificate_renewal" {
  description = "Certificate renewal settings"
  value       = module.bastion_openvpn.certificate_renewal_settings
}

output "module_configuration" {
  description = "Module configuration details"
  value = {
    ami_type            = "Amazon Linux 2023"
    instance_type       = var.instance_type
    purpose             = "Bastion + OpenVPN for small teams"
    certificate_renewal = "Enabled with automatic renewal"
    monitoring          = "CloudWatch logs and alarms enabled"
    estimated_cost      = "~$5/month for t4g.nano instance (5-10 users)"
  }
}