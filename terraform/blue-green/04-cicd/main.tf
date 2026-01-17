provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "blue-green-lab"
}

# --- Remote State Data Sources ---
# Read state from Layer 1 (01-core) to get IAM Roles
data "terraform_remote_state" "core" {
  backend = "local"
  config = {
    path = "../01-core/terraform.tfstate"
  }
}

# Read state from Layer 2 (02-infra) to get ASG and Target Group
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../02-infra/terraform.tfstate"
  }
}

# Read state from Layer 3 (03-monitoring) to get CloudWatch Alarm
data "terraform_remote_state" "monitoring" {
  backend = "local"
  config = {
    path = "../03-monitoring/terraform.tfstate"
  }
}
