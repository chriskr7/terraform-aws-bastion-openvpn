resource "aws_instance" "bastion_openvpn" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id

  vpc_security_group_ids      = [aws_security_group.bastion_openvpn.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_openvpn.name

  source_dest_check = false

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh.tpl", {
    name_prefix                     = local.name_prefix
    s3_bucket_name                  = var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].id : var.s3_bucket_name
    enable_openvpn                  = true
    vpc_cidr                        = var.vpc_cidr
    cloudwatch_log_group            = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.bastion_openvpn[0].name : ""
    aws_region                      = data.aws_region.current.name
    openvpn_port                    = var.openvpn_port
    openvpn_protocol                = var.openvpn_protocol
    openvpn_cidr                    = var.openvpn_cidr
    openvpn_dns_servers             = join(",", var.openvpn_dns_servers)
    elastic_ip                      = "" # EIP is created after instance, so we rely on dynamic discovery
    enable_certificate_auto_renewal = var.enable_certificate_auto_renewal
  }))

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = var.root_volume_encrypted
    kms_key_id            = var.root_volume_kms_key_id
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring = var.enable_detailed_monitoring

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-instance"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "bastion_openvpn" {
  instance = aws_instance.bastion_openvpn.id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip"
  })
}
