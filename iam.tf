

# IAM Role
resource "aws_iam_role" "bastion_openvpn" {
  name = var.iam_role_name != "" ? var.iam_role_name : "${local.name_prefix}-role"
  path = var.iam_role_path

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy
resource "aws_iam_role_policy" "bastion_openvpn" {
  name = "${local.name_prefix}-policy"
  role = aws_iam_role.bastion_openvpn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeInstances",
            "ec2:DescribeTags"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData",
            "cloudwatch:GetMetricStatistics",
            "cloudwatch:ListMetrics"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ssm:UpdateInstanceInformation",
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel",
            "ec2messages:AcknowledgeMessage",
            "ec2messages:DeleteMessage",
            "ec2messages:FailMessage",
            "ec2messages:GetEndpoint",
            "ec2messages:GetMessages",
            "ec2messages:SendReply"
          ]
          Resource = "*"
        }
      ],
      var.create_s3_bucket || var.s3_bucket_name != "" ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            var.create_s3_bucket ? aws_s3_bucket.openvpn_config[0].arn : "arn:aws:s3:::${var.s3_bucket_name}",
            var.create_s3_bucket ? "${aws_s3_bucket.openvpn_config[0].arn}/*" : "arn:aws:s3:::${var.s3_bucket_name}/*"
          ]
        }
      ] : [],
      var.additional_iam_policy_statements
    )
  })
}

# Additional IAM Policy Attachments
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_iam_policy_arns)

  role       = aws_iam_role.bastion_openvpn.name
  policy_arn = each.value
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "bastion_openvpn" {
  name = var.iam_instance_profile_name != "" ? var.iam_instance_profile_name : "${local.name_prefix}-profile"
  role = aws_iam_role.bastion_openvpn.name
}
