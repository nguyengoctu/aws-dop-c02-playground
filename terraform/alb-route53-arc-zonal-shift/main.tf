provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet_1a" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_1b" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
}

// route table
resource "aws_route_table" "rtb" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "igw_route" {
    route_table_id = aws_route_table.rtb.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "rtb_assoc_1a" {
    subnet_id = aws_subnet.subnet_1a.id
    route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rtb_assoc_1b" {
    subnet_id = aws_subnet.subnet_1b.id
    route_table_id = aws_route_table.rtb.id
}

output "vpc_id" {
    value = aws_vpc.vpc.id
}

output "subnet_1a_id" {
    value = aws_subnet.subnet_1a.id
}

output "subnet_1b_id" {
    value = aws_subnet.subnet_1b.id
}
    
    