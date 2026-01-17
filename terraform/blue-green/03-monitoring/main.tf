provider "aws" {
  region = var.region
}

# Read state from Layer 2 (Infra) to get Load Balancer info
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../02-infra/terraform.tfstate"
  }
}
