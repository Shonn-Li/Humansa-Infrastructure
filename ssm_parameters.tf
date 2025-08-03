# Database connection parameters
resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/${var.environment}/db_host"
  type  = "String"
  value = split(":", aws_db_instance.humansa_postgres.endpoint)[0]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-host"
  }
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project_name}/${var.environment}/db_port"
  type  = "String"
  value = tostring(aws_db_instance.humansa_postgres.port)
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-port"
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/${var.environment}/db_username"
  type  = "String"
  value = var.db_username
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-username"
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/${var.environment}/db_password"
  type  = "SecureString"
  value = var.db_password
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-password"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/${var.environment}/db_name"
  type  = "String"
  value = var.db_name
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-name"
  }
}

# ALB and deployment parameters
resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/${var.project_name}/${var.environment}/alb_dns_name"
  type  = "String"
  value = aws_lb.humansa_alb.dns_name
  
  tags = {
    Name = "${var.project_name}-${var.environment}-alb-dns-name"
  }
}

resource "aws_ssm_parameter" "target_group_arn" {
  name  = "/${var.project_name}/${var.environment}/target_group_arn"
  type  = "String"
  value = aws_lb_target_group.humansa_tg.arn
  
  tags = {
    Name = "${var.project_name}-${var.environment}-target-group-arn"
  }
}

resource "aws_ssm_parameter" "asg_name" {
  name  = "/${var.project_name}/${var.environment}/asg_name"
  type  = "String"
  value = aws_autoscaling_group.ml_server.name
  
  tags = {
    Name = "${var.project_name}-${var.environment}-asg-name"
  }
}

# Container image tag for deployments
resource "aws_ssm_parameter" "image_tag" {
  name  = "/${var.project_name}/${var.environment}/image_tag"
  type  = "String"
  value = "latest"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-image-tag"
  }
}