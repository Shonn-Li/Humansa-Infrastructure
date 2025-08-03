# RDS PostgreSQL Database
resource "aws_db_instance" "humansa_postgres" {
  identifier = "${var.project_name}-${var.environment}-db"
  
  # Engine configuration
  engine               = "postgres"
  engine_version       = var.postgres_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  
  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432
  
  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  
  # High availability
  multi_az = var.multi_az
  
  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period
  
  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval            = var.monitoring_interval
  monitoring_role_arn           = aws_iam_role.rds_monitoring.arn
  
  # Other settings
  auto_minor_version_upgrade  = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-db-final-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db"
  }
}

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

# Individual database parameters
resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/${var.environment}/db_host"
  type  = "String"
  value = split(":", aws_db_instance.humansa_postgres.endpoint)[0]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-host"
  }
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project_name}/${var.environment}/db_port"
  type  = "String"
  value = tostring(aws_db_instance.humansa_postgres.port)
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-port"
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/${var.environment}/db_username"
  type  = "String"
  value = var.db_username
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-username"
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/${var.environment}/db_password"
  type  = "SecureString"
  value = var.db_password
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-password"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/${var.environment}/db_name"
  type  = "String"
  value = var.db_name
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-name"
  }
}