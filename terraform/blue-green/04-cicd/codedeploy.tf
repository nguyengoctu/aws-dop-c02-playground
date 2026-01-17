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

  # Deployment Style: Blue/Green with traffic control (i.e., using ALB)
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    target_group_info {
      # Send traffic to Target Group from Layer 2
      name = data.terraform_remote_state.infra.outputs.target_group_name
    }
  }

  # IMPORTANT: For Blue/Green, we attach the initial ASG here.
  # CodeDeploy will copy this ASG to create a new "Green" fleet.
  autoscaling_groups = [data.terraform_remote_state.infra.outputs.asg_name]

  # Configuration for handling old/new Instances (Problem requirement: Terminate old instances)
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "CONTINUE_DEPLOYMENT"
      wait_time_in_minutes = 0
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5 # Keep for 5 minutes then terminate
    }

    # IMPORTANT: Configure CodeDeploy to AUTOMATICALLY copy old ASG to new ASG (Green Fleet)
    # If missing, it defaults to "Manually provision instances" and causes NO_INSTANCES error
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }

  # Deploy Config: Require at least 50% traffic routing
  deployment_config_name = aws_codedeploy_deployment_config.custom_fifty_percent.id

  # Alarm Config for automatic Rollback on high Latency (Layer 3 Monitoring)
  alarm_configuration {
    alarms  = [data.terraform_remote_state.monitoring.outputs.alarm_name]
    enabled = true
  }

  # Auto rollback if deployment fails OR Alarm triggers
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  # CRITICAL: Ignore changes on autoscaling_groups as CodeDeploy manages it
  # After first deployment, CodeDeploy terminates old ASG and creates new ASG with auto-generated name
  # If not ignored, Terraform tries to find old (deleted) ASG and errors out
  lifecycle {
    ignore_changes = [autoscaling_groups]
  }
}

# --- Custom Deployment Configuration (Problem Requirement) ---
# "Create a custom deployment configuration... defined as 50%"
resource "aws_codedeploy_deployment_config" "custom_fifty_percent" {
  deployment_config_name = "${var.project_name}-min-50-percent"

  minimum_healthy_hosts {
    type  = "FLEET_PERCENT"
    value = 50
  }
}
