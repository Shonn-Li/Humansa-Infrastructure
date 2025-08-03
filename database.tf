# RDS PostgreSQL Database
resource "aws_db_instance" "humansa_postgres" {
  identifier = "${var.project_name}-${var.environment}-db"
  
  # Engine configuration
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.medium"
  allocated_storage    = 20
  max_allocated_storage = 250
  storage_type         = "gp3"
  storage_encrypted    = true
  
  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432
  
  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.humansa_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  
  # High availability
  multi_az               = false
  
  # Backup configuration
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  
  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval            = 60
  monitoring_role_arn           = aws_iam_role.rds_monitoring.arn
  
  # Other settings
  auto_minor_version_upgrade  = true
  deletion_protection        = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-db-final-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db"
  }
}

# Read Replica for scaling read operations
# Not needed for 300-400 concurrent requests
# Uncomment if you need read replicas in the future
# resource "aws_db_instance" "humansa_postgres_replica" {
#   count = 1
#   
#   identifier             = "${var.project_name}-${var.environment}-db-replica-${count.index + 1}"
#   replicate_source_db    = aws_db_instance.humansa_postgres.identifier
#   instance_class         = "db.t3.small"
#   publicly_accessible    = false
#   auto_minor_version_upgrade = false
#   
#   # Performance Insights
#   performance_insights_enabled          = true
#   performance_insights_retention_period = 7
#   
#   tags = {
#     Name = "${var.project_name}-${var.environment}-db-replica-${count.index + 1}"
#   }
# }

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Parameter Store for database connection string
resource "aws_ssm_parameter" "db_connection_string" {
  name  = "/${var.project_name}/${var.environment}/db/connection_string"
  type  = "SecureString"
  value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.humansa_postgres.endpoint}/${var.db_name}"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-connection-string"
  }
}

# CloudWatch Alarms for Database
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors database CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.humansa_postgres.id
  }
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-db-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10737418240" # 10GB in bytes
  alarm_description   = "This metric monitors database free storage"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.humansa_postgres.id
  }
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors database connections"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.humansa_postgres.id
  }
}