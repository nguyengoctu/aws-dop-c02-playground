// EC2
resource "aws_instance" "web_a" {
    ami = "ami-07ff62358b87c7116" # amazon linux
    instance_type = "t3a.micro"
    vpc_security_group_ids = [aws_security_group.alb_sg.id]
    subnet_id = aws_subnet.subnet_1a.id
    associate_public_ip_address = true
    user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              echo "<h1>Hello from AZ-A</h1>" > /var/www/html/index.html
              EOF
              
}

resource "aws_instance" "web_b" {
    ami = "ami-07ff62358b87c7116" # amazon linux
    instance_type = "t3a.micro"
    vpc_security_group_ids = [aws_security_group.alb_sg.id]
    subnet_id = aws_subnet.subnet_1b.id
    associate_public_ip_address = true
    user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              echo "<h1>Hello from AZ-B</h1>" > /var/www/html/index.html
              EOF
              
}

resource "aws_lb" "main_alb" {
    name = "main-alb"
    security_groups = [aws_security_group.alb_sg.id]
    subnets = [aws_subnet.subnet_1a.id, aws_subnet.subnet_1b.id]
    internal = false
    load_balancer_type = "application"
    enable_cross_zone_load_balancing = false
    enable_zonal_shift = true
}

resource "aws_lb_target_group" "tg" {
    name = "tg"
    port = 80
    protocol = "HTTP"
    target_type = "instance"
    vpc_id = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "tg_a_attachment" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.web_a.id
}

resource "aws_lb_target_group_attachment" "tg_b_attachment" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.web_b.id
}

resource "aws_lb_listener" "http_listener" {
    load_balancer_arn = aws_lb.main_alb.arn
    port = 80
    protocol = "HTTP"
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.tg.arn
    }
}

output "alb_dns" {
  value = aws_lb.main_alb.dns_name
}