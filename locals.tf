# Common locals definition
locals {
  name_prefix = var.name != "" ? var.name : "bastion-openvpn"

  # Default tags
  common_tags = merge(
    var.tags,
    {
      Module = "terraform-aws-bastion-openvpn"
      Name   = local.name_prefix
    }
  )
}
