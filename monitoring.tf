# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-${var.environment}-alarms"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-alarms"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ml_server" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}"
  retention_in_days = 30
  
  tags = {
    Name = "${var.project_name}-${var.environment}-ml-server-logs"
  }
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${var.project_name}-${var.environment}"
  retention_in_days = 30
  
  tags = {
    Name = "${var.project_name}-${var.environment}-app-logs"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "humansa" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.humansa_alb.arn_suffix],
            [".", "RequestCount", ".", "."],
            [".", "ActiveConnectionCount", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.ml_server.name],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.humansa_postgres.id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", aws_elasticache_replication_group.humansa_redis.id],
            [".", "DatabaseMemoryUsagePercentage", ".", "."],
            [".", "CacheHits", ".", "."],
            [".", "CacheMisses", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Redis Metrics"
        }
      }
    ]
  })
}

# Additional Application-level Alarms
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "ALB response time is too high"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.humansa_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "ALB has unhealthy hosts"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.humansa_tg.arn_suffix
    LoadBalancer = aws_lb.humansa_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_4xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "High number of 4XX errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.humansa_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "High number of 5XX errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.humansa_alb.arn_suffix
  }
}