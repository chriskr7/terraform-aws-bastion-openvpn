# terraform-aws-bastion-openvpn

[![Terraform
  Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/YOUR_GITHUB_USERNAME/bastion-openvpn/aws)

> 한국어 문서는 [README_KO.md](./README_KO.md)를 참고하세요. / For Korean documentation, please refer to [README_KO.md](./README_KO.md).

A Terraform module that provides a secure bastion host with integrated OpenVPN server on AWS, designed for individuals or small teams (5-10 users).

## Features

- 🚀 **Simple Single-Instance Solution**: Bastion host and OpenVPN server in one EC2 instance
- 👥 **Designed for Small Teams**: Optimized for individual developers or teams of 5-10 users
- 💰 **Cost-Effective**: Single t4g.nano instance costs only ~$3/month
- ⚡ **ARM64 Only**: Exclusively uses AWS Graviton (ARM64) processors for better price-performance
- 🔒 **Secure Access**: Combined bastion SSH and OpenVPN for secure remote access
- 📊 **CloudWatch Integration**: Built-in monitoring and logging
- 🎯 **Easy Setup**: Simple configuration with sensible defaults
- 🔐 **Automatic Certificate Management**: Automated certificate renewal for continuous service
- 📦 **S3 Backend**: Secure storage for OpenVPN configurations and certificates
- 🐧 **Amazon Linux 2023**: Built on the latest Amazon Linux 2023 AMI

## Quick Start

### Basic Usage

```hcl
module "bastion_openvpn" {
  source = "./modules/bastion-openvpn"

  vpc_id    = "vpc-xxxxxxxxx"
  subnet_id = "subnet-xxxxxx"  # Single public subnet

  tags = {
    Environment = "dev"
  }
}
```

### Production Configuration for Small Teams

```hcl
module "bastion_openvpn" {
  source = "./modules/bastion-openvpn"

  name      = "prod-bastion-vpn"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]  # Deploy to single public subnet

  # Instance configuration (t4g.nano supports 5-10 concurrent users)
  instance_type = "t4g.nano"  # ~$3/month, handles 5-10 users with light traffic
  key_name      = "my-key"

  # OpenVPN access control
  openvpn_client_cidrs = ["1.2.3.4/32", "5.6.7.8/32"]  # Restrict to team IPs

  # Bastion SSH access control
  ssh_client_cidrs = ["1.2.3.4/32", "5.6.7.8/32"]  # Restrict SSH access

  # Monitoring
  enable_cloudwatch_alarms = true
  alarm_sns_topic_arn     = aws_sns_topic.alerts.arn

  # Certificate management
  enable_certificate_auto_renewal = true
  certificate_renewal_days        = 30

  tags = {
    Environment = "production"
    Team        = "DevOps"
  }
}
```

## Requirements

| Name         | Version                        |
| ------------ | ------------------------------ |
| terraform    | >= 1.0                         |
| aws          | ~> 5.0                         |
| AMI          | Amazon Linux 2023 (ARM64 only) |
| Architecture | ARM64/Graviton only            |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | ~> 5.0  |

## Inputs

### Required Variables

| Name      | Description                    | Type   |
| --------- | ------------------------------ | ------ |
| vpc_id    | VPC ID                         | string |
| subnet_id | Subnet ID for bastion instance | string |

### Optional Variables

#### EC2 Configuration

| Name                       | Description                                        | Type   | Default                             |
| -------------------------- | -------------------------------------------------- | ------ | ----------------------------------- |
| name                       | Resource name prefix                               | string | "" (auto-generated)                 |
| vpc_cidr                   | VPC CIDR block for routing and VPN configuration   | string | "10.0.0.0/16"                       |
| instance_type              | EC2 instance type (must be ARM64/Graviton: t4g.\*) | string | "t4g.nano"                          |
| ami_id                     | AMI ID to use                                      | string | "" (latest Amazon Linux 2023 ARM64) |
| key_name                   | EC2 key pair name                                  | string | ""                                  |
| enable_detailed_monitoring | Enable detailed monitoring                         | bool   | false                               |

#### EBS Configuration

| Name                   | Description                   | Type   | Default |
| ---------------------- | ----------------------------- | ------ | ------- |
| root_volume_size       | Root volume size (GB)         | number | 20      |
| root_volume_type       | Root volume type              | string | "gp3"   |
| root_volume_encrypted  | Enable root volume encryption | bool   | true    |
| root_volume_kms_key_id | KMS key ID                    | string | ""      |

#### OpenVPN Configuration

| Name                        | Description                                      | Type         | Default                |
| --------------------------- | ------------------------------------------------ | ------------ | ---------------------- |
| openvpn_port                | OpenVPN port                                     | number       | 1194                   |
| openvpn_protocol            | OpenVPN protocol                                 | string       | "udp"                  |
| enable_openvpn_tcp_fallback | Enable TCP fallback                              | bool         | true                   |
| openvpn_network             | Client network                                   | string       | "10.8.0.0"             |
| openvpn_netmask             | Network mask                                     | string       | "255.255.255.0"        |
| openvpn_netmask_bits        | Network mask bits                                | number       | 24                     |
| openvpn_dns_servers         | DNS servers                                      | list(string) | ["8.8.8.8", "8.8.4.4"] |
| openvpn_client_cidrs        | Allowed client CIDRs                             | list(string) | ["0.0.0.0/0"]          |
| openvpn_push_routes         | Additional routes                                | list(string) | []                     |
| openvpn_cipher              | Encryption algorithm                             | string       | "AES-256-GCM"          |
| openvpn_auth                | Authentication algorithm                         | string       | "SHA256"               |
| openvpn_compress            | Enable compression                               | bool         | true                   |
| enable_ssh_from_vpn         | Allow SSH from VPN                               | bool         | true                   |
| enable_client_to_client     | Allow VPN clients to communicate with each other | bool         | false                  |
| allow_duplicate_cn          | Allow multiple clients with same certificate     | bool         | false                  |
| ssh_client_cidrs            | CIDR blocks allowed to SSH directly (bastion)    | list(string) | []                     |

#### S3 Configuration

| Name             | Description      | Type   | Default |
| ---------------- | ---------------- | ------ | ------- |
| create_s3_bucket | Create S3 bucket | bool   | true    |
| s3_bucket_name   | S3 bucket name   | string | ""      |

#### IAM Configuration

| Name                             | Description                      | Type         | Default             |
| -------------------------------- | -------------------------------- | ------------ | ------------------- |
| iam_role_name                    | IAM role name                    | string       | "" (auto-generated) |
| iam_role_path                    | IAM role path                    | string       | "/"                 |
| iam_instance_profile_name        | Instance profile name            | string       | "" (auto-generated) |
| additional_iam_policy_arns       | Additional IAM policy ARNs       | list(string) | []                  |
| additional_iam_policy_statements | Additional IAM policy statements | list(any)    | []                  |

#### Security Group Configuration

| Name                            | Description                     | Type         | Default             |
| ------------------------------- | ------------------------------- | ------------ | ------------------- |
| security_group_name             | Security group name             | string       | "" (auto-generated) |
| additional_security_group_rules | Additional security group rules | list(object) | []                  |

#### CloudWatch Configuration

| Name                               | Description                      | Type   | Default             |
| ---------------------------------- | -------------------------------- | ------ | ------------------- |
| enable_cloudwatch_logs             | Enable CloudWatch logs           | bool   | true                |
| cloudwatch_log_group_name          | Log group name                   | string | "" (auto-generated) |
| cloudwatch_log_retention_days      | Log retention period             | number | 30                  |
| cloudwatch_log_group_kms_key_id    | KMS key ID                       | string | ""                  |
| enable_cloudwatch_alarms           | Enable CloudWatch alarms         | bool   | false               |
| alarm_sns_topic_arn                | SNS topic ARN                    | string | ""                  |
| openvpn_connection_alarm_threshold | Connection count alarm threshold | number | 50                  |

#### Certificate Renewal Configuration

| Name                            | Description                     | Type   | Default |
| ------------------------------- | ------------------------------- | ------ | ------- |
| certificate_lifetime_days       | Certificate lifetime (days)     | number | 365     |
| certificate_renewal_days        | Days before expiration to renew | number | 30      |
| enable_certificate_auto_renewal | Enable automatic renewal        | bool   | true    |

#### Other Configuration

| Name | Description            | Type        | Default |
| ---- | ---------------------- | ----------- | ------- |
| tags | Tags for all resources | map(string) | {}      |

For the complete list of variables, see [variables.tf](./variables.tf).

## Outputs

| Name                         | Description                                     |
| ---------------------------- | ----------------------------------------------- |
| instance_id                  | EC2 instance ID                                 |
| instance_public_ip           | EC2 instance public IP                          |
| instance_private_ip          | EC2 instance private IP                         |
| elastic_ip                   | Elastic IP address                              |
| security_group_id            | Security group ID                               |
| iam_role_arn                 | IAM role ARN                                    |
| iam_instance_profile_name    | IAM instance profile name                       |
| s3_bucket_name               | S3 bucket name for OpenVPN configuration        |
| s3_bucket_arn                | S3 bucket ARN for OpenVPN configuration         |
| cloudwatch_log_group_name    | CloudWatch log group name                       |
| openvpn_connection_info      | OpenVPN connection information                  |
| ssh_connection_string        | SSH connection string for bastion access        |
| generate_client_cert_command | Command to generate OpenVPN client certificates |
| certificate_renewal_settings | Certificate renewal configuration settings      |

## OpenVPN Client Setup

> **⏱️ Installation Time on Amazon Linux 2023**
>
> OpenVPN installation compiles from source and takes approximately **5-10 minutes**:
>
> - Development Tools installation: 2-3 minutes
> - OpenVPN source download: 30 seconds
> - Compilation: 2-3 minutes
> - Installation and configuration: 1-2 minutes
>
> Monitor progress: `sudo tail -f /var/log/user-data.log`

### 1. Generate Client Certificate

```bash
# SSH to the bastion instance using Elastic IP
ssh -i your-key.pem ec2-user@<elastic-ip>

# Generate client configuration
sudo /usr/local/bin/generate-client-cert.sh client-name
```

### 2. Download Configuration File

```bash
# Download from S3
aws s3 cp s3://<bucket-name>/clients/client-name.ovpn .
```

### 3. Connect to OpenVPN

#### macOS

```bash
brew install openvpn
sudo openvpn --config client-name.ovpn
```

#### Windows

1. Install [OpenVPN GUI](https://openvpn.net/client-connect-vpn-for-windows/)
2. Import configuration file
3. Connect

#### Linux

```bash
sudo apt-get install openvpn
sudo openvpn --config client-name.ovpn
```

## Architecture

```
┌─────────────────────────────┐
│        Internet             │
└──────────┬──────────────────┘
           │
      [Elastic IP]
           │
    ┌──────┴──────┐
    │   Bastion   │
    │      +      │
    │   OpenVPN   │
    └──────┬──────┘
           │
    ┌──────┴──────┐
    │   Private   │
    │  Resources  │
    └─────────────┘
```

### Simple Design

- **Single EC2 Instance**: One t4g.nano instance running both services
- **Elastic IP**: Stable public IP for consistent access
- **Dual Function**: SSH bastion + OpenVPN server
- **S3 Backend**: Secure storage for VPN configurations and certificates

## Cost Breakdown

| Component               | Monthly Cost  | Details                                |
| ----------------------- | ------------- | -------------------------------------- |
| EC2 Instance (t4g.nano) | ~$3           | ARM-based, suitable for 5-10 users     |
| Elastic IP              | $0            | Free when attached                     |
| EBS Storage (20GB)      | ~$1.60        | gp3 volume                             |
| S3 Storage              | <$1           | OpenVPN configurations                 |
| **Total**               | **~$5/month** | Perfect for individuals or small teams |

## Instance Size Recommendations

Choose the right instance size based on your team's needs:

| Instance Type  | vCPUs | RAM   | Max Concurrent Users | Use Case                       | Monthly Cost |
| -------------- | ----- | ----- | -------------------- | ------------------------------ | ------------ |
| **t4g.nano**   | 2     | 0.5GB | 5-10                 | Light admin access, small team | ~$3          |
| **t4g.micro**  | 2     | 1GB   | 15-25                | General traffic, medium team   | ~$6          |
| **t4g.small**  | 2     | 2GB   | 30-50                | Heavy usage, larger team       | ~$12         |
| **t4g.medium** | 2     | 4GB   | 50-100               | High traffic, large team       | ~$24         |

> **Important**: This module exclusively supports AWS Graviton (ARM64) instances. All instance types must be from the t4g, m6g, c6g, or r6g families. x86 instances are not supported.

> **Note**: User limits assume typical VPN usage patterns with light to moderate traffic. Heavy data transfer or resource-intensive operations may require larger instances.

## Monitoring

### CloudWatch Metrics

- CPU utilization
- Memory utilization
- OpenVPN connection count
- Network traffic

### Logs

- System logs: `/aws/ec2/<name>/system`
- OpenVPN logs: `/aws/ec2/<name>/openvpn`

## Features

### Automatic Certificate Renewal

Automatically renews OpenVPN certificates to prevent service interruption.

```hcl
# Certificate auto-renewal settings
enable_certificate_auto_renewal = true
certificate_lifetime_days      = 365  # Certificate validity period
certificate_renewal_days       = 30   # Renew X days before expiration
```

Features:

- Daily automatic checks (Cron)
- Renews both server and client certificates
- CloudWatch metrics and alarms
- Automatic S3 backup

## Security Considerations

1. **Access Restriction**: Limit `openvpn_client_cidrs` to specific IPs
2. **SSH Bastion Access**: Use `ssh_client_cidrs` to restrict direct SSH access to specific IPs only
3. **Key Management**: Encrypted storage in S3 bucket
4. **Regular Updates**: Keep AMI and packages up to date
5. **Monitoring**: Configure CloudWatch alarms
6. **Certificate Management**: Prevent expiration with auto-renewal

## Important Considerations

### Operating System

**This module uses Amazon Linux 2023 (AL2023)** as the base AMI for the bastion/OpenVPN instance.

### Simple Deployment

This module creates a straightforward single-instance deployment:

```hcl
# Bastion + OpenVPN configuration
module "bastion_openvpn" {
  source = "./modules/bastion-openvpn"

  vpc_id    = var.vpc_id
  subnet_id = var.public_subnet_id  # Single public subnet

  # Optional: restrict access
  openvpn_client_cidrs = ["1.2.3.4/32"]
  ssh_client_cidrs     = ["1.2.3.4/32"]
}
```

**What you get**:

- 1 EC2 instance (t4g.nano by default)
- 1 Elastic IP for stable access
- Security group with proper rules
- S3 bucket for configurations
- CloudWatch logs and monitoring

## Cleanup

```bash
# Simple destroy - removes all resources
terraform destroy
```

## Troubleshooting

### OpenVPN Connection Failure

```bash
# Check security group
aws ec2 describe-security-groups --group-ids <sg-id>

# Check service status
ssh ec2-user@<ip> "sudo systemctl status openvpn-server@server"
```

### SSH Connection Issues

```bash
# Check instance status
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].State'

# Check Elastic IP
aws ec2 describe-addresses \
  --filters "Name=instance-id,Values=<instance-id>"

# View user-data logs
aws logs tail /aws/ec2/<name>/user-data --follow
```

## Use Cases

### Perfect For:

- **Individual Developers**: Secure access to private AWS resources
- **Small Teams (5-10 users)**: Shared bastion and VPN access with light traffic
- **Development Environments**: Cost-effective remote access solution
- **Proof of Concepts**: Quick setup for testing and demos

### Not Recommended For:

- Large teams (use AWS Client VPN or similar)
- High-availability production environments
- Heavy concurrent usage (>50 users)

## Examples

- [Simple Setup](./examples/simple)
- [Complete Setup](./examples/complete)

## Contributing

Issues and PRs are welcome!

## License

Apache 2.0 License. See [LICENSE](./LICENSE) file for details.
