# --- Application Load Balancer ---
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  # Sử dụng Security Group và Subnets lấy từ Layer 1 (01-core)
  security_groups = [data.terraform_remote_state.core.outputs.alb_sg_id]
  subnets         = data.terraform_remote_state.core.outputs.subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# --- Target Group ---
# Đây là Target Group "Blue" ban đầu
resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.core.outputs.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # Deregistration delay giúp connection cũ thoát ra từ từ (30s cho lab nhanh hơn)
  deregistration_delay = 30
}

# --- Listener ---
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
