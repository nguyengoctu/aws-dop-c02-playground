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
# Đọc trạng thái từ Layer 1 (01-core) để lấy IAM Roles
data "terraform_remote_state" "core" {
  backend = "local"
  config = {
    path = "../01-core/terraform.tfstate"
  }
}

# Đọc trạng thái từ Layer 2 (02-infra) để lấy ASG và Target Group
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../02-infra/terraform.tfstate"
  }
}
