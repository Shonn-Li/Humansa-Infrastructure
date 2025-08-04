# Terraform configuration for Humansa Production Environment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Configure S3 backend for state management (following YouWoAI pattern)
  backend "s3" {
    bucket         = "humansa-terraform-state"
    key            = "state/terraform.tfstate"
    region         = "ap-east-1"
    encrypt        = true
    dynamodb_table = "humansa-terraform-state-locking"
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  subnet_count = 2
}

# Security Module
module "security" {
  source = "../../modules/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  ml_server_port    = 5000
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
}

# Load Balancer Module
module "load_balancer" {
  source = "../../modules/load-balancer"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.public_subnet_ids
  security_group_id          = module.security.alb_security_group_id
  domain_name                = var.domain_name
  route53_zone_id            = var.route53_zone_id
  enable_deletion_protection = var.enable_deletion_protection
}

# Database Module
module "database" {
  source = "../../modules/database"

  project_name                          = var.project_name
  environment                           = var.environment
  db_name                               = var.db_name
  db_username                           = var.db_username
  db_password                           = var.db_password
  instance_class                        = var.db_instance_class
  allocated_storage                     = var.db_allocated_storage
  max_allocated_storage                 = var.db_max_allocated_storage
  multi_az                              = var.db_multi_az
  backup_retention_period               = var.db_backup_retention_period
  performance_insights_enabled          = var.db_performance_insights_enabled
  performance_insights_retention_period = var.db_performance_insights_retention_period
  monitoring_interval                   = var.db_monitoring_interval
  deletion_protection                   = var.db_deletion_protection
  skip_final_snapshot                   = var.db_skip_final_snapshot
  db_subnet_group_name                  = module.networking.db_subnet_group_name
  security_group_id                     = module.security.database_security_group_id
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  instance_type     = var.instance_type
  min_instances     = var.min_instances
  desired_instances = var.desired_instances
  max_instances     = var.max_instances
  root_volume_size  = var.root_volume_size
  ssh_public_key    = var.ssh_public_key
  github_repo       = var.github_repo
  security_group_id = module.security.ml_server_security_group_id
  subnet_ids        = module.networking.public_subnet_ids
  target_group_arn  = module.load_balancer.target_group_arn
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_name             = var.project_name
  environment              = var.environment
  alarm_email              = var.alarm_email
  autoscaling_group_name   = module.compute.autoscaling_group_name
  scale_up_policy_arn      = module.compute.scale_up_policy_arn
  scale_down_policy_arn    = module.compute.scale_down_policy_arn
  db_instance_id           = module.database.db_instance_id
  target_group_arn_suffix  = module.load_balancer.target_group_arn_suffix
  load_balancer_arn_suffix = module.load_balancer.load_balancer_arn_suffix
}

# SSM Parameters for API tokens and GitHub PAT
resource "aws_ssm_parameter" "api_tokens" {
  count = length(var.api_tokens)
  name  = "/${var.project_name}/${var.environment}/api/token_${count.index + 1}"
  type  = "SecureString"
  value = var.api_tokens[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-api-token-${count.index + 1}"
  }
}

resource "aws_ssm_parameter" "github_pat" {
  name  = "/${var.project_name}/${var.environment}/github/pat"
  type  = "SecureString"
  value = var.github_pat

  tags = {
    Name = "${var.project_name}-${var.environment}-github-pat"
  }
}

# Additional SSM parameters for deployment automation
resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/${var.project_name}/${var.environment}/alb_dns_name"
  type  = "String"
  value = module.load_balancer.load_balancer_dns_name

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-dns-name"
  }
}

resource "aws_ssm_parameter" "target_group_arn" {
  name  = "/${var.project_name}/${var.environment}/target_group_arn"
  type  = "String"
  value = module.load_balancer.target_group_arn

  tags = {
    Name = "${var.project_name}-${var.environment}-target-group-arn"
  }
}

resource "aws_ssm_parameter" "asg_name" {
  name  = "/${var.project_name}/${var.environment}/asg_name"
  type  = "String"
  value = module.compute.autoscaling_group_name

  tags = {
    Name = "${var.project_name}-${var.environment}-asg-name"
  }
}

resource "aws_ssm_parameter" "image_tag" {
  name  = "/${var.project_name}/${var.environment}/image_tag"
  type  = "String"
  value = "latest"

  tags = {
    Name = "${var.project_name}-${var.environment}-image-tag"
  }
}