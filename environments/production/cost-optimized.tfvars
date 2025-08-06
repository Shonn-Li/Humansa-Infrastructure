# Cost-Optimized Configuration for Humansa
# This reduces costs by ~60-70% while maintaining basic functionality

# Database Configuration - REDUCED
db_instance_class               = "db.t3.micro" # Was: db.t3.small
db_backup_retention_period      = 7             # Was: 30 days
db_performance_insights_enabled = false         # Was: true
db_monitoring_interval          = 0             # Was: 60 (disabled)
db_deletion_protection          = false         # Was: true (easier teardown)

# Instance Configuration - SIGNIFICANTLY REDUCED
instance_type = "t3.small" # Was: t3.medium (saves ~50%)
# DON'T use t3.micro - only 1GB RAM, ML models will crash
min_instances     = 1  # Was: 2 (saves 50% on base compute)
desired_instances = 1  # Was: 2
max_instances     = 2  # Was: 4
root_volume_size  = 30 # Was: 100 GB - this is disk storage per EC2
# 30GB is enough for OS + Docker + ML server + logs

# Load Balancer - Consider removal for further savings
enable_deletion_protection = false # Was: true (easier teardown)

# Estimated Monthly Costs:
# EC2: 1 × t3.small (2GB RAM) = ~$15/month
# RDS: 1 × db.t3.micro (1GB RAM) = ~$13/month  
# ALB: ~$20/month
# Storage: 30GB EBS = ~$3/month
# Data Transfer: ~$7/month
# TOTAL: ~$58/month (saves $92-112/month from original)

# Scaling Notes:
# - RDS can be scaled up/down with 5-10 min downtime
# - EC2 instances can be added/removed instantly
# - Consider time-based scaling to save more