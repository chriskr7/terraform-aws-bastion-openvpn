
resource "aws_cloudwatch_log_group" "bastion_openvpn" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = var.cloudwatch_log_group_name != "" ? var.cloudwatch_log_group_name : "/aws/ec2/${local.name_prefix}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "openvpn_connections" {
  count = var.enable_cloudwatch_alarms && var.alarm_sns_topic_arn != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-openvpn-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "OpenVPNConnections"
  namespace           = "${local.name_prefix}/OpenVPN"
  period              = "300"
  statistic           = "Average"
  threshold           = var.openvpn_connection_alarm_threshold
  alarm_description   = "Alert when OpenVPN connections are high"

  alarm_actions = [var.alarm_sns_topic_arn]

  tags = local.common_tags
}

# Certificate Expiration Alarm
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  count = var.enable_cloudwatch_alarms && var.enable_certificate_auto_renewal && var.alarm_sns_topic_arn != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-certificate-expiry"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ServerCertificateDaysRemaining"
  namespace           = "Bastion-OpenVPN"
  period              = "86400" # 1 day
  statistic           = "Minimum"
  threshold           = var.certificate_renewal_days
  alarm_description   = "OpenVPN server certificate expiration approaching"
  treat_missing_data  = "breaching" # Trigger alarm if no data

  alarm_actions = [var.alarm_sns_topic_arn]

  tags = local.common_tags
}
