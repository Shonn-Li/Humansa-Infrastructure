output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.humansa_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.humansa_alb.zone_id
}

output "api_endpoint" {
  description = "HTTPS endpoint for the Humansa API"
  value       = "https://humansa.youwo.ai"
}

output "database_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.humansa_postgres.endpoint
  sensitive   = true
}

# output "database_read_endpoints" {
#   description = "RDS PostgreSQL read replica endpoints"
#   value       = [for replica in aws_db_instance.humansa_postgres_replica : replica.endpoint]
#   sensitive   = true
# }

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_replication_group.humansa_redis.primary_endpoint_address
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.humansa_vpc.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ml_server.name
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.humansa.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = aws_sns_topic.alarms.arn
}