# Terraform configuration for Humansa Staging Environment

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
  
  # Configure S3 backend for state management
  backend "s3" {
    bucket         = "humansa-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "ap-east-1"
    encrypt        = true
    dynamodb_table = "humansa-terraform-locks"
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
  vpc_id           = module.networking.vpc_id
  ml_server_port   = 5000
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
}

# Load Balancer Module
module "load_balancer" {
  source = "../../modules/load-balancer"
  
  project_name               = var.project_name
  environment               = var.environment
  vpc_id                    = module.networking.vpc_id
  subnet_ids                = module.networking.public_subnet_ids
  security_group_id         = module.security.alb_security_group_id
  domain_name               = var.domain_name
  route53_zone_id           = var.route53_zone_id
  enable_deletion_protection = var.enable_deletion_protection
}

# Database Module - Smaller instance for staging
module "database" {
  source = "../../modules/database"
  
  project_name                             = var.project_name
  environment                             = var.environment
  db_name                                 = var.db_name
  db_username                             = var.db_username
  db_password                             = var.db_password
  instance_class                          = "db.t3.micro"  # Smaller for staging
  allocated_storage                       = 10             # Less storage for staging
  max_allocated_storage                   = 50             # Lower max for staging
  multi_az                               = false           # No Multi-AZ for staging
  backup_retention_period                = 7              # Shorter retention for staging
  performance_insights_enabled           = false          # Disabled for cost savings
  performance_insights_retention_period  = 7
  monitoring_interval                    = 0              # Disabled for cost savings
  deletion_protection                    = false          # Disabled for easy cleanup
  skip_final_snapshot                    = true           # Skip for staging
  db_subnet_group_name                   = module.networking.db_subnet_group_name
  security_group_id                      = module.security.database_security_group_id
}

# Compute Module - Smaller instances for staging
module "compute" {
  source = "../../modules/compute"
  
  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  instance_type     = "t3.small"           # Smaller for staging
  min_instances     = 1                    # Single instance for staging
  desired_instances = 1
  max_instances     = 2                    # Lower max for staging
  root_volume_size  = 50                   # Smaller volume for staging
  ssh_public_key    = var.ssh_public_key
  github_repo       = var.github_repo
  security_group_id = module.security.ml_server_security_group_id
  subnet_ids        = module.networking.public_subnet_ids
  target_group_arn  = module.load_balancer.target_group_arn
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_name               = var.project_name
  environment               = var.environment
  alarm_email               = var.alarm_email
  autoscaling_group_name    = module.compute.autoscaling_group_name
  scale_up_policy_arn       = module.compute.scale_up_policy_arn
  scale_down_policy_arn     = module.compute.scale_down_policy_arn
  db_instance_id            = module.database.db_instance_id
  target_group_arn_suffix   = module.load_balancer.target_group_arn_suffix
  load_balancer_arn_suffix  = module.load_balancer.load_balancer_arn_suffix
}

# SSM Parameters
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