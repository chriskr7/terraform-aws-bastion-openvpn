# terraform-aws-fck-nat-openvpn/variables.tf

# Basic Configuration
variable "name" {
  description = "Resource name prefix (defaults to 'fck-nat-openvpn' if empty)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to deploy bastion instance"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for routing and VPN configuration"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type (must be ARM64/Graviton: t4g, c6g, m6g, or r6g families)"
  type        = string
  default     = "t4g.nano"

  validation {
    condition = can(regex("^(t4g|c6g|m6g|r6g)\\.", var.instance_type))
    error_message = "Instance type must be from ARM64/Graviton families: t4g, c6g, m6g, or r6g. x86 instances are not supported."
  }
}

variable "ami_id" {
  description = "AMI ID to use (uses latest Amazon Linux 2023 ARM64 AMI if empty)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name (for SSH access, optional)"
  type        = string
  default     = ""
}

variable "enable_detailed_monitoring" {
  description = "Enable EC2 detailed monitoring"
  type        = bool
  default     = false
}


# EBS Configuration
variable "root_volume_size" {
  description = "Root volume size (GB)"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Enable root volume encryption"
  type        = bool
  default     = true
}

variable "root_volume_kms_key_id" {
  description = "KMS key ID for root volume encryption (optional)"
  type        = string
  default     = ""
}


# OpenVPN Configuration
variable "openvpn_port" {
  description = "OpenVPN server port"
  type        = number
  default     = 1194
}

variable "openvpn_protocol" {
  description = "OpenVPN protocol (udp/tcp)"
  type        = string
  default     = "udp"

  validation {
    condition     = contains(["udp", "tcp"], var.openvpn_protocol)
    error_message = "OpenVPN protocol must be 'udp' or 'tcp'."
  }
}

variable "enable_openvpn_tcp_fallback" {
  description = "Enable TCP fallback port when using UDP"
  type        = bool
  default     = true
}

variable "openvpn_network" {
  description = "OpenVPN client network (e.g., 10.8.0.0)"
  type        = string
  default     = "10.8.0.0"
}

variable "openvpn_netmask" {
  description = "OpenVPN client network netmask"
  type        = string
  default     = "255.255.255.0"
}

variable "openvpn_netmask_bits" {
  description = "OpenVPN client network netmask bits"
  type        = number
  default     = 24
}

variable "openvpn_cidr" {
  description = "OpenVPN network CIDR (e.g., 10.8.0.0/24)"
  type        = string
  default     = "10.8.0.0/24"
}

variable "openvpn_dns_servers" {
  description = "DNS servers to push to OpenVPN clients"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "openvpn_client_cidrs" {
  description = "Client CIDR blocks allowed to connect to OpenVPN"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "openvpn_push_routes" {
  description = "Additional routes to push to OpenVPN clients"
  type        = list(string)
  default     = []
}

variable "openvpn_cipher" {
  description = "OpenVPN encryption algorithm"
  type        = string
  default     = "AES-256-GCM"
}

variable "openvpn_auth" {
  description = "OpenVPN authentication algorithm"
  type        = string
  default     = "SHA256"
}

variable "openvpn_compress" {
  description = "Enable OpenVPN compression"
  type        = bool
  default     = true
}

variable "enable_ssh_from_vpn" {
  description = "Allow SSH access from VPN clients"
  type        = bool
  default     = true
}

variable "enable_client_to_client" {
  description = "Allow VPN clients to communicate with each other"
  type        = bool
  default     = false
}

variable "allow_duplicate_cn" {
  description = "Allow multiple clients with same certificate"
  type        = bool
  default     = false
}

variable "ssh_client_cidrs" {
  description = "CIDR blocks allowed to SSH to the instance (bastion access)"
  type        = list(string)
  default     = []
}

# S3 Configuration
variable "create_s3_bucket" {
  description = "Create S3 bucket"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name (optional - auto-generated if not provided)"
  type        = string
  default     = ""
}

# IAM Configuration
variable "iam_role_name" {
  description = "IAM role name (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "iam_role_path" {
  description = "IAM role path"
  type        = string
  default     = "/"
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "additional_iam_policy_arns" {
  description = "List of additional IAM policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "additional_iam_policy_statements" {
  description = "Additional IAM policy statements"
  type        = list(any)
  default     = []
}

# Security Group Configuration
variable "security_group_name" {
  description = "Security group name (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "additional_security_group_rules" {
  description = "Additional security group rules"
  type = list(object({
    type             = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    description      = optional(string)
  }))
  default = []
}

# CloudWatch Configuration
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch log group name (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention period (days)"
  type        = number
  default     = 30
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "KMS key ID for CloudWatch log encryption (optional)"
  type        = string
  default     = ""
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = false
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = ""
}

variable "openvpn_connection_alarm_threshold" {
  description = "OpenVPN connection count alarm threshold"
  type        = number
  default     = 50
}


# Custom Configuration
variable "custom_user_data" {
  description = "Additional user data script"
  type        = string
  default     = ""
}


# Certificate Auto-renewal Configuration
variable "certificate_lifetime_days" {
  description = "OpenVPN certificate lifetime (days)"
  type        = number
  default     = 365
}

variable "certificate_renewal_days" {
  description = "Days before expiration to start renewal"
  type        = number
  default     = 30
}

variable "enable_certificate_auto_renewal" {
  description = "Enable automatic certificate renewal"
  type        = bool
  default     = true
}

