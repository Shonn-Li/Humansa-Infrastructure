# SSM Parameters for Humansa ML Server
# These parameters are used by the deployment scripts and ML server

# Infrastructure parameters (automatically populated)
resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/humansa/production/alb_dns_name"
  type  = "String"
  value = module.load_balancer.load_balancer_dns_name

  tags = {
    Name = "humansa-production-alb-dns-name"
  }
}

resource "aws_ssm_parameter" "asg_name" {
  name  = "/humansa/production/asg_name"
  type  = "String"
  value = module.compute.autoscaling_group_name

  tags = {
    Name = "humansa-production-asg-name"
  }
}

resource "aws_ssm_parameter" "ml_tg_arn" {
  name  = "/humansa/production/ml_tg_arn"
  type  = "String"
  value = module.compute.target_group_arn

  tags = {
    Name = "humansa-production-ml-target-group-arn"
  }
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/humansa/production/vpc_id"
  type  = "String"
  value = module.networking.vpc_id

  tags = {
    Name = "humansa-production-vpc-id"
  }
}

# Database parameters
resource "aws_ssm_parameter" "db_host" {
  name  = "/humansa/production/db_host"
  type  = "String"
  value = split(":", module.database.db_instance_endpoint)[0]

  tags = {
    Name = "humansa-production-db-host"
  }
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/humansa/production/db_port"
  type  = "String"
  value = "5432"

  tags = {
    Name = "humansa-production-db-port"
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/humansa/production/db_username"
  type  = "String"
  value = var.db_username

  tags = {
    Name = "humansa-production-db-username"
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/humansa/production/db_password"
  type  = "SecureString"
  value = var.db_password

  tags = {
    Name = "humansa-production-db-password"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/humansa/production/db_name"
  type  = "String"
  value = var.db_name

  tags = {
    Name = "humansa-production-db-name"
  }
}

# ML Server configuration (defaults)
resource "aws_ssm_parameter" "ml_server_image_tag" {
  name  = "/humansa/production/ml_server_image_tag"
  type  = "String"
  value = "latest"

  tags = {
    Name = "humansa-production-ml-server-image-tag"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# GitHub PAT placeholder (must be updated manually)
resource "aws_ssm_parameter" "github_pat" {
  name  = "/humansa/production/github_pat"
  type  = "SecureString"
  value = "PLACEHOLDER_UPDATE_MANUALLY"

  tags = {
    Name = "humansa-production-github-pat"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# ML Server URL (internal)
resource "aws_ssm_parameter" "ml_server_url" {
  name  = "/humansa/production/ml_server_url"
  type  = "String"
  value = "http://${module.load_balancer.load_balancer_dns_name}"

  tags = {
    Name = "humansa-production-ml-server-url"
  }
}