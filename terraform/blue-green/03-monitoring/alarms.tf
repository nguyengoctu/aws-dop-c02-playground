# --- CloudWatch Metric Alarm ---
# Alarm when Web App Latency increases beyond allowed threshold
resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "${var.project_name}-alb-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"                  # Number of consecutive periods breaching threshold (1 means notify immediately)
  metric_name         = "TargetResponseTime" # Metric measuring Target Group latency
  namespace           = "AWS/ApplicationELB"
  period              = "60" # Sampling period (seconds)
  statistic           = "Average"
  threshold           = "0.5" # Alarm threshold: 0.5 seconds (500ms)
  alarm_description   = "This metric monitors ALB Target Response Time"
  treat_missing_data  = "notBreaching"

  # Configure Dimensions to specify which Load Balancer and Target Group
  dimensions = {
    # ALB and Target Group from Layer 2
    # LoadBalancer ARN suffix (e.g., app/my-alb/123456)
    LoadBalancer = data.terraform_remote_state.infra.outputs.alb_arn_suffix
    TargetGroup  = data.terraform_remote_state.infra.outputs.target_group_arn_suffix
  }
}
