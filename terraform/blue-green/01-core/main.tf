provider "aws" {
  region = var.region
}

# Lấy thông tin VPC mặc định và Subnets để chia sẻ cho các layer khác
# (Trong thực tế nên tạo VPC riêng, nhưng lab này dùng default cho gọn)
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
