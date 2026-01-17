# --- CloudWatch Metric Alarm ---
# Báo động khi độ trễ (Latency) của Web App tăng cao quá mức cho phép
resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "${var.project_name}-alb-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"                  # Số lần thống kê liên tiếp vi phạm (1 lần là báo ngay)
  metric_name         = "TargetResponseTime" # Metric đo độ trễ của Target Group
  namespace           = "AWS/ApplicationELB"
  period              = "60" # Chu kỳ lấy mẫu (giây)
  statistic           = "Average"
  threshold           = "0.5" # Ngưỡng báo động: 0.5 giây (500ms)
  alarm_description   = "This metric monitors ALB Target Response Time"
  treat_missing_data  = "notBreaching"

  # Cấu hình Dimensions để chỉ đích danh Load Balancer và Target Group nào
  dimensions = {
    # ALB và Target Group lấy từ Layer 2
    # LoadBalancer ARN suffix (VD: app/my-alb/123456)
    LoadBalancer = data.terraform_remote_state.infra.outputs.alb_arn_suffix
    TargetGroup  = data.terraform_remote_state.infra.outputs.target_group_arn_suffix
  }
}
