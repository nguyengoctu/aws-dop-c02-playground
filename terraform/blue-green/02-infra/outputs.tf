output "target_group_name" {
  value = aws_lb_target_group.main.name
}

output "asg_name" {
  value = aws_autoscaling_group.main.name
}

output "alb_dns_name" {
  description = "Dia chi DNS de truy cap vao Load Balancer"
  value       = aws_lb.main.dns_name
}
