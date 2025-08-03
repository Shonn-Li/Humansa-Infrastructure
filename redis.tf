# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "humansa_redis" {
  replication_group_id       = "${var.project_name}-${var.environment}-redis"
  description               = "Redis cluster for Humansa ML server caching"
  node_type                 = var.redis_node_type
  num_cache_clusters        = var.redis_num_nodes
  port                      = 6379
  subnet_group_name         = aws_elasticache_subnet_group.humansa_cache_subnet_group.name
  security_group_ids        = [aws_security_group.redis.id]
  
  # Engine configuration
  engine_version       = "7.1"
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  
  # High availability
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  # Backup configuration
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
  
  # Maintenance
  maintenance_window = "sun:05:00-sun:07:00"
  
  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled        = true
  auth_token                = random_password.redis_auth_token.result
  
  # Notifications
  notification_topic_arn = aws_sns_topic.alarms.arn
  
  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
  }
}

# Redis Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "${var.project_name}-${var.environment}-redis-params"
  
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
  
  parameter {
    name  = "timeout"
    value = "300"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-redis-params"
  }
}

# Generate secure auth token for Redis
resource "random_password" "redis_auth_token" {
  length  = 32
  special = true
  override_special = "!&#$^<>-"
}

# Store Redis connection details in Parameter Store
resource "aws_ssm_parameter" "redis_endpoint" {
  name  = "/${var.project_name}/${var.environment}/redis/endpoint"
  type  = "String"
  value = aws_elasticache_replication_group.humansa_redis.primary_endpoint_address
  
  tags = {
    Name = "${var.project_name}-${var.environment}-redis-endpoint"
  }
}

resource "aws_ssm_parameter" "redis_auth_token" {
  name  = "/${var.project_name}/${var.environment}/redis/auth_token"
  type  = "SecureString"
  value = random_password.redis_auth_token.result
  
  tags = {
    Name = "${var.project_name}-${var.environment}-redis-auth-token"
  }
}

# CloudWatch Alarms for Redis
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.humansa_redis.id
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis memory usage"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.humansa_redis.id
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "This metric monitors Redis evictions"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.humansa_redis.id
  }
}