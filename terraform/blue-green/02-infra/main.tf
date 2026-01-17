provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "blue-green-lab"
}

variable "instance_type" {
  default = "t3a.micro"
}

# --- Remote State Data Source ---
# Đọc thông tin (State) từ Layer 1 (01-core)
data "terraform_remote_state" "core" {
  backend = "local"

  config = {
    path = "../01-core/terraform.tfstate"
  }
}
