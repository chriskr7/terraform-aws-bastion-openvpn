
# S3 Bucket - For storing OpenVPN configurations
resource "aws_s3_bucket" "openvpn_config" {
  count = var.create_s3_bucket ? 1 : 0

  bucket        = var.s3_bucket_name != "" ? var.s3_bucket_name : "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Allow bucket deletion even if it contains objects

  tags = merge(
    local.common_tags,
    {
      Purpose = "OpenVPN-Config-Storage"
    }
  )
}

resource "aws_s3_bucket_versioning" "openvpn_config" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.openvpn_config[0].id

  versioning_configuration {
    status = "Disabled" # Disable versioning to avoid deletion issues
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "openvpn_config" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.openvpn_config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "openvpn_config" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.openvpn_config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
