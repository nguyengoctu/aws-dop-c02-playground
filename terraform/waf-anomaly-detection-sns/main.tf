terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- Networking ---

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "waf-lab-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "waf-lab-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "waf-lab-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "waf-lab-subnet-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "waf-lab-rt-public" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb_sg" {
  name        = "waf-lab-alb-sg"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Application Load Balancer ---

resource "aws_lb" "main" {
  name               = "waf-lab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "waf-lab-alb" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Welcome to the WAF Lab! Your request was ALLOWED."
      status_code  = "200"
    }
  }
}

# --- AWS WAFv2 ---

resource "aws_wafv2_web_acl" "main" {
  name        = "waf-lab-acl"
  description = "WAF ACL for Anomaly Detection Lab"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-lab-acl"
    sampled_requests_enabled   = true
  }

  # Rule to BLOCK specific requests (simulating an attack)
  # We block requests with header "x-attack: true"
  rule {
    name     = "BlockAttackHeader"
    priority = 1

    action {
      block {}
    }

    statement {
      byte_match_statement {
        search_string = "true"
        field_to_match {
          single_header {
            name = "x-attack"
          }
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
        positional_constraint = "EXACTLY"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockAttackHeader"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# --- Logging & Monitoring ---

# WAF Log Group must start with 'aws-waf-logs-' for CloudWatch Logs destination
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-tdojo"
  retention_in_days = 7
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}

# Metric Filter to capture BLOCK actions
resource "aws_cloudwatch_log_metric_filter" "blocked_requests" {
  name           = "WAFBlockedRequestsFilter"
  pattern        = "{ $.action = \"BLOCK\" }"
  log_group_name = aws_cloudwatch_log_group.waf_logs.name

  metric_transformation {
    name          = "BlockedRequests"
    namespace     = "WAF/AnomalyDetection"
    value         = "1"
    default_value = "0"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "waf-anomaly-alerts"
}

# CloudWatch Alarm with Anomaly Detection
resource "aws_cloudwatch_metric_alarm" "anomaly_detection" {
  alarm_name          = "WAF-BlockedRequests-Anomaly"
  comparison_operator = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "ad1"
  alarm_description   = "Alarm when BlockedRequests deviate from expected baseline"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)" # 2 standard deviations
    label       = "BlockedRequests (Expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = aws_cloudwatch_log_metric_filter.blocked_requests.metric_transformation[0].name
      namespace   = aws_cloudwatch_log_metric_filter.blocked_requests.metric_transformation[0].namespace
      period      = 60 # 1 minute for faster testing, use 300 for prod
      stat        = "Sum"
    }
  }
}

# --- Outputs ---

output "alb_url" {
  value = aws_lb.main.dns_name
}
