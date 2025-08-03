# Application Load Balancer
resource "aws_lb" "humansa_alb" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  enable_deletion_protection = true
  enable_http2              = true
  idle_timeout              = 60
  
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# S3 bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-${var.environment}-alb-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-alb-logs"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

# Target Group
resource "aws_lb_target_group" "humansa_tg" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.humansa_vpc.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
  
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.humansa_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.humansa_cert.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.humansa_tg.arn
  }
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.humansa_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = "redirect"
    
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ACM Certificate
resource "aws_acm_certificate" "humansa_cert" {
  domain_name       = "humansa.youwo.ai"
  validation_method = "DNS"
  
  subject_alternative_names = [
    "*.humansa.youwo.ai"
  ]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-cert"
  }
}

# DNS validation for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.humansa_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "humansa_cert" {
  certificate_arn         = aws_acm_certificate.humansa_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route53 A record for ALB
resource "aws_route53_record" "humansa_alb" {
  zone_id = var.route53_zone_id
  name    = "humansa.youwo.ai"
  type    = "A"
  
  alias {
    name                   = aws_lb.humansa_alb.dns_name
    zone_id                = aws_lb.humansa_alb.zone_id
    evaluate_target_health = true
  }
}

# Data sources
data "aws_elb_service_account" "main" {}
data "aws_caller_identity" "current" {}