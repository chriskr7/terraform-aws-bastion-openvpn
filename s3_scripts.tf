# Upload script files to S3

resource "aws_s3_object" "cert_renewal_script" {
  count = var.enable_certificate_auto_renewal ? 1 : 0

  bucket  = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
  key     = "scripts/cert_renewal.sh"
  
  # Render the template with variables
  content = templatefile("${path.module}/scripts/cert_renewal.sh.tpl", {
    s3_bucket_name            = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
    certificate_renewal_days  = var.certificate_renewal_days
    certificate_lifetime_days = var.certificate_lifetime_days
    aws_region                = data.aws_region.current.name
    cloudwatch_namespace      = "${local.name_prefix}/OpenVPN"
  })

  server_side_encryption = "AES256"
}



# Upload OpenVPN installation script for Amazon Linux 2023
resource "aws_s3_object" "install_openvpn_al2023_script" {
  count = 1

  bucket  = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
  key     = "scripts/install_openvpn_al2023.sh"
  content = file("${path.module}/scripts/install_openvpn_al2023.sh")

  server_side_encryption = "AES256"
}

# Upload rendered OpenVPN client generation script
resource "aws_s3_object" "generate_openvpn_client_script" {
  count = 1

  bucket = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
  key    = "scripts/generate_openvpn_client.sh"

  # Render the template with variables
  content = templatefile("${path.module}/scripts/generate_openvpn_client.sh.tpl", {
    aws_region                  = data.aws_region.current.name
    s3_bucket_name              = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
    openvpn_protocol            = var.openvpn_protocol
    openvpn_port                = var.openvpn_port
    openvpn_cipher              = var.openvpn_cipher
    openvpn_auth                = var.openvpn_auth
    openvpn_compress            = var.openvpn_compress
    enable_openvpn_tcp_fallback = var.enable_openvpn_tcp_fallback
  })

  server_side_encryption = "AES256"
}

# Upload rendered OpenVPN metrics script
resource "aws_s3_object" "openvpn_metrics_script" {
  count = 1

  bucket = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
  key    = "scripts/openvpn_metrics.sh"

  content = templatefile("${path.module}/scripts/openvpn_metrics.sh.tpl", {
    name_prefix = local.name_prefix
    aws_region  = data.aws_region.current.name
  })

  server_side_encryption = "AES256"
}

# Upload OpenVPN server setup script
resource "aws_s3_object" "setup_openvpn_server_script" {
  count = 1

  bucket = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
  key    = "scripts/setup_openvpn_server.sh"

  content = templatefile("${path.module}/scripts/setup_openvpn_server.sh.tpl", {
    openvpn_port                = var.openvpn_port
    openvpn_protocol            = var.openvpn_protocol
    openvpn_network             = var.openvpn_network
    openvpn_netmask             = var.openvpn_netmask
    openvpn_netmask_bits        = var.openvpn_netmask_bits
    openvpn_dns_servers         = var.openvpn_dns_servers
    openvpn_cipher              = var.openvpn_cipher
    openvpn_auth                = var.openvpn_auth
    openvpn_compress            = var.openvpn_compress
    openvpn_push_routes         = var.openvpn_push_routes
    enable_openvpn_tcp_fallback = var.enable_openvpn_tcp_fallback
    enable_client_to_client     = var.enable_client_to_client
    allow_duplicate_cn          = var.allow_duplicate_cn
  })

  server_side_encryption = "AES256"
}

# Upload CloudWatch setup script
resource "aws_s3_object" "setup_cloudwatch_script" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  bucket = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
  key    = "scripts/setup_cloudwatch.sh"

  content = templatefile("${path.module}/scripts/setup_cloudwatch.sh.tpl", {
    cloudwatch_log_group = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.bastion_openvpn[0].name : ""
    name_prefix          = local.name_prefix
    enable_openvpn       = true
  })

  server_side_encryption = "AES256"
}

# Upload OpenVPN PKI setup script
resource "aws_s3_object" "setup_openvpn_pki_script" {
  count = 1

  bucket  = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
  key     = "scripts/setup_openvpn_pki.sh"
  content = file("${path.module}/scripts/setup_openvpn_pki.sh")

  server_side_encryption = "AES256"
}