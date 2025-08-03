# Global Configuration
variable "aws_region" {
  description = "AWS region for Humansa deployment"
  type        = string
  default     = "ap-east-1" # Hong Kong - closer to mainland China
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "humansa"
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # TODO: Restrict in production
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
  type        = string
  default     = "humansa"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage in GB"
  type        = number
  default     = 250
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "db_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "db_performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

variable "db_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds"
  type        = number
  default     = 60
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when deleting"
  type        = bool
  default     = false
}

# Load Balancer Configuration
variable "domain_name" {
  description = "Domain name for the load balancer"
  type        = string
  default     = "humansa-staging.youwo.ai"
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID for youwo.ai domain"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for load balancer"
  type        = bool
  default     = true
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
  type        = string
  default     = "t3.medium"
}

variable "min_instances" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "desired_instances" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 4
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 100
}

# Monitoring Configuration
variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
}

# GitHub Configuration
variable "github_pat" {
  description = "GitHub Personal Access Token for deployment"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository for Humansa ML server"
  type        = string
  default     = "youwoai/humansa-ml-server"
}

# SSH Configuration
variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
}