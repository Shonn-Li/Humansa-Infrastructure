variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  type        = string
}

variable "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  type        = string
}

variable "db_instance_id" {
  description = "RDS instance ID"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch metrics"
  type        = string
}

variable "load_balancer_arn_suffix" {
  description = "Load balancer ARN suffix for CloudWatch metrics"
  type        = string
}