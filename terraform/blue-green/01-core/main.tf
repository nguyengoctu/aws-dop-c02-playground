provider "aws" {
  region = var.region
}

# Get default VPC and Subnets info to share with other layers
# (In reality should create separate VPC, but using default for simplicity in this lab)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # Filter out us-east-1e because t3a.micro is not supported there.
  # We explicitly list common supported AZs.
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}
