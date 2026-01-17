# --- CodeDeploy Application ---
resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = "${var.project_name}-app"
}

# --- CodeDeploy Deployment Group (Blue/Green) ---
resource "aws_codedeploy_deployment_group" "bg_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${var.project_name}-bg-group"
  service_role_arn      = data.terraform_remote_state.core.outputs.codedeploy_service_role_arn

  # Deployment Style: Blue/Green với traffic control (nghĩa là dùng ALB)
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    target_group_info {
      # Gửi traffic vào Target Group của Layer 2
      name = data.terraform_remote_state.infra.outputs.target_group_name
    }
  }

  # QUAN TRỌNG: Với Blue/Green, ta gắn ASG ban đầu vào đây.
  # CodeDeploy sẽ copy ASG này để tạo ra "Green" fleet mới.
  autoscaling_groups = [data.terraform_remote_state.infra.outputs.asg_name]

  # Cấu hình xử lý Instances cũ/mới (Yêu cầu đề bài: Terminate instances cũ)
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "CONTINUE_DEPLOYMENT"
      wait_time_in_minutes = 0
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5 # Giữ lại 5 phút rồi xóa
    }

    # QUAN TRỌNG: Cấu hình để CodeDeploy TỰ ĐỘNG copy ASG cũ ra ASG mới (Green Fleet)
    # Nếu thiếu dòng này, nó sẽ chọn "Manually provision instances" và gây lỗi NO_INSTANCES
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }

  # Cấu hình Deploy: Yêu cầu traffic route ít nhất 50%
  deployment_config_name = aws_codedeploy_deployment_config.custom_fifty_percent.id

  # Tự động rollback nếu deploy thất bại
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  # CRITICAL: Ignore changes trên autoscaling_groups vì CodeDeploy tự quản lý
  # Sau lần deployment đầu tiên, CodeDeploy sẽ terminate ASG cũ và tạo ASG mới với tên tự gen
  # Nếu không ignore, Terraform sẽ cố tìm ASG cũ (đã bị xóa) và báo lỗi
  lifecycle {
    ignore_changes = [autoscaling_groups]
  }
}

# --- Custom Deployment Configuration (Yêu cầu đề bài) ---
# "Create a custom deployment configuration... defined as 50%"
resource "aws_codedeploy_deployment_config" "custom_fifty_percent" {
  deployment_config_name = "${var.project_name}-min-50-percent"

  minimum_healthy_hosts {
    type  = "FLEET_PERCENT"
    value = 50
  }
}
