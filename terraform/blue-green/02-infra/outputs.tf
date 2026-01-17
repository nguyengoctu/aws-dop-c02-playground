output "target_group_name" {
  value = aws_lb_target_group.main.name
}

output "asg_name" {
  value = aws_autoscaling_group.main.name
}

output "alb_dns_name" {
  description = "DNS address to access Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.main.arn_suffix
}
