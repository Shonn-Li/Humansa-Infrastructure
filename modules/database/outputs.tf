output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.humansa_postgres.id
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.humansa_postgres.endpoint
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.humansa_postgres.port
}

output "db_connection_string_parameter" {
  description = "SSM parameter name for database connection string"
  value       = aws_ssm_parameter.db_connection_string.name
}