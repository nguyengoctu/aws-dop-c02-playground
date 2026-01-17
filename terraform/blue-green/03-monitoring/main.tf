provider "aws" {
  region = var.region
}

# Đọc state từ Layer 2 (Infra) để lấy thông tin Load Balancer
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../02-infra/terraform.tfstate"
  }
}
