variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

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

variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository for Humansa ML server"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for ML servers"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the Auto Scaling Group"
  type        = list(string)
}

variable "target_group_arn" {
  description = "Target group ARN for the load balancer"
  type        = string
}