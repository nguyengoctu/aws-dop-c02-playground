# Tìm AMI Amazon Linux 2023 mới nhất
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# --- Launch Template ---
# Định nghĩa cấu hình cho các EC2 instances
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  # Gắn Instance Profile (IAM Role) lấy từ Layer 1
  iam_instance_profile {
    name = data.terraform_remote_state.core.outputs.ec2_profile_name
  }

  vpc_security_group_ids = [data.terraform_remote_state.core.outputs.ec2_sg_id]

  # User Data: Script chạy khi instance khởi động lần đầu
  # Cài đặt CodeDeploy Agent (Bắt buộc cho CodeDeploy)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum install -y ruby wget
              cd /home/ec2-user
              wget https://aws-codedeploy-${var.region}.s3.${var.region}.amazonaws.com/latest/install
              chmod +x ./install
              ./install auto
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }
}

# --- Auto Scaling Group ---
# Quản lý số lượng EC2 instances
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = data.terraform_remote_state.core.outputs.subnet_ids
  max_size            = 4
  min_size            = 2
  desired_capacity    = 2

  # Gắn vào Target Group để nhận Traffic từ ALB
  target_group_arns = [aws_lb_target_group.main.arn]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}
