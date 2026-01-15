// security group
resource "aws_security_group" "alb_sg" {
    vpc_id = aws_vpc.vpc.id
    name = "alb-sg"
    description = "Security group for ALB"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}