# Ultra Cost-Optimized Configuration for Humansa
# For API-gateway only (no local ML models)

# Database Configuration - MINIMAL
db_instance_class               = "db.t3.micro" # 1GB RAM - enough for API logs
db_backup_retention_period      = 7             # Minimal backups
db_performance_insights_enabled = false         # Not needed
db_monitoring_interval          = 0             # Disabled
db_deletion_protection          = false

# Instance Configuration - ULTRA MINIMAL
instance_type     = "t3.micro" # 1GB RAM - enough for API gateway!
min_instances     = 2          # MUST BE 2 for zero-downtime deployments!
desired_instances = 2          # Rolling updates need at least 2
max_instances     = 3          # Allow scale if needed
root_volume_size  = 20         # 20GB is plenty for API gateway

# Load Balancer 
enable_deletion_protection = false

# NEW Monthly Costs:
# EC2: 2 × t3.micro (1GB) = ~$15/month (for zero downtime)
# RDS: 1 × db.t3.micro = ~$13/month  
# ALB: ~$20/month (required for load balancing between 2 instances)
# Storage: 40GB total = ~$4/month
# TOTAL: ~$52/month (saves $98-118/month!)

# What This Handles:
# - API request routing to OpenAI/Anthropic
# - Response streaming
# - Basic logging
# - Light concurrent users (up to ~50-100)

# Zero-Downtime Deployment Strategy:
# - ALB routes traffic between 2 instances
# - Ansible updates one instance at a time
# - Users experience no downtime
# - Each deployment takes ~10-15 minutes total

# When to Scale Up:
# - If you add local ML models (need t3.small+)
# - If you implement heavy caching
# - If concurrent users > 100
# - If memory usage > 800MB consistently