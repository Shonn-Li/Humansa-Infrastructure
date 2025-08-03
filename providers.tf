terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  # Backend configuration for state management
  backend "s3" {
    bucket         = "humansa-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-east-1"
    encrypt        = true
    dynamodb_table = "humansa-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Humansa"
    }
  }
}