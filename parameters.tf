# Store API tokens in Parameter Store
resource "aws_ssm_parameter" "api_tokens" {
  count = length(var.api_tokens)
  
  name  = "/${var.project_name}/${var.environment}/api/token_${count.index}"
  type  = "SecureString"
  value = var.api_tokens[count.index]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-api-token-${count.index}"
  }
}

# Store GitHub PAT for deployment automation
resource "aws_ssm_parameter" "github_pat" {
  name  = "/${var.project_name}/${var.environment}/github/pat"
  type  = "SecureString"
  value = var.github_pat
  
  tags = {
    Name = "${var.project_name}-${var.environment}-github-pat"
  }
}

# Application configuration parameters
resource "aws_ssm_parameter" "app_config" {
  for_each = {
    "server_port"     = "5000"
    "log_level"       = "INFO"
    "max_connections" = "1000"
    "timeout"         = "30"
    "region"          = var.aws_region
  }
  
  name  = "/${var.project_name}/${var.environment}/app/${each.key}"
  type  = "String"
  value = each.value
  
  tags = {
    Name = "${var.project_name}-${var.environment}-app-${each.key}"
  }
}

# Database configuration (read-only endpoints)
# Commented out since we're not using read replicas for this scale
# resource "aws_ssm_parameter" "db_read_endpoints" {
#   count = length(aws_db_instance.humansa_postgres_replica)
#   
#   name  = "/${var.project_name}/${var.environment}/db/read_endpoint_${count.index}"
#   type  = "String"
#   value = aws_db_instance.humansa_postgres_replica[count.index].endpoint
#   
#   tags = {
#     Name = "${var.project_name}-${var.environment}-db-read-endpoint-${count.index}"
#   }
# }