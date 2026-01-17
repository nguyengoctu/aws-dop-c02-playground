# --- Security Group cho Load Balancer ---
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Cho phep HTTP truy cap vao ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP tu Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security Group cho EC2 Instance ---
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Cho phep HTTP tu ALB va SSH/SSM"
  vpc_id      = data.aws_vpc.default.id

  # Chỉ cho phép Traffic từ ALB
  ingress {
    description     = "HTTP tu ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
