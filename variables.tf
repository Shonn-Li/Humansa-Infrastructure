variable "aws_region" {
  description = "AWS region for Humansa deployment"
  default     = "ap-east-1" # Hong Kong - closer to mainland China
}

variable "environment" {
  description = "Environment name"
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  default     = "humansa"
}

# Database Configuration
variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  default     = "humansa"
}

# Route53 Configuration
variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID for youwo.ai domain"
  type        = string
}

# API Configuration
variable "api_tokens" {
  description = "List of API tokens for authentication"
  type        = list(string)
  sensitive   = true
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for ML servers"
  default     = "t3.medium"
}

variable "min_instances" {
  description = "Minimum number of instances in ASG"
  default     = 2
}

variable "desired_instances" {
  description = "Desired number of instances in ASG"
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of instances in ASG"
  default     = 4
}

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  default     = "cache.t3.micro"
}

variable "redis_num_nodes" {
  description = "Number of Redis nodes"
  default     = 1
}

# Monitoring
variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
}

# GitHub Configuration (for deployment automation)
variable "github_pat" {
  description = "GitHub Personal Access Token for deployment"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository for Humansa ML server"
  default     = "youwoai/humansa-ml-server"
}

# SSH Key
variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
}