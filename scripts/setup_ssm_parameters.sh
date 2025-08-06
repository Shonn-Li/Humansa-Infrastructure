#!/bin/bash

# Setup SSM Parameters for Humansa ML Server
# This script creates/updates all required SSM parameters

set -e

echo "Setting up SSM parameters for Humansa ML Server..."

# Get database endpoint from terraform output
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier humansa-postgres \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text 2>/dev/null || echo "")

if [ -z "$DB_ENDPOINT" ]; then
  echo "Warning: Could not find RDS instance. Using placeholder."
  DB_ENDPOINT="humansa-postgres.cluster-xxxxx.us-west-1.rds.amazonaws.com"
fi

# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names humansa-production-ml-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null || echo "")

if [ -z "$TG_ARN" ]; then
  echo "Warning: Could not find target group. Using placeholder."
  TG_ARN="arn:aws:elasticloadbalancing:us-west-1:xxxxx:targetgroup/humansa-production-ml-tg/xxxxx"
fi

# Database parameters
echo "Setting database parameters..."
aws ssm put-parameter \
  --name "/humansa/production/db_host" \
  --type "String" \
  --value "$DB_ENDPOINT" \
  --overwrite \
  --description "Humansa RDS endpoint"

aws ssm put-parameter \
  --name "/humansa/production/db_port" \
  --type "String" \
  --value "5432" \
  --overwrite \
  --description "PostgreSQL port"

aws ssm put-parameter \
  --name "/humansa/production/db_user" \
  --type "String" \
  --value "postgres" \
  --overwrite \
  --description "Database username"

# Note: DB password should already exist from terraform
# If not, set it manually:
# aws ssm put-parameter \
#   --name "/humansa/production/db_password" \
#   --type "SecureString" \
#   --value "YOUR_SECURE_PASSWORD" \
#   --overwrite \
#   --description "Database password"

aws ssm put-parameter \
  --name "/humansa/production/db_name" \
  --type "String" \
  --value "humansa" \
  --overwrite \
  --description "Database name"

# Infrastructure parameters
echo "Setting infrastructure parameters..."
aws ssm put-parameter \
  --name "/humansa/production/ml_tg_arn" \
  --type "String" \
  --value "$TG_ARN" \
  --overwrite \
  --description "ML server target group ARN"

aws ssm put-parameter \
  --name "/humansa/production/ml_server_image_tag" \
  --type "String" \
  --value "latest" \
  --overwrite \
  --description "Current ML server Docker image tag"

# Environment configuration
echo "Setting environment parameters..."
aws ssm put-parameter \
  --name "/humansa/production/environment" \
  --type "String" \
  --value "production" \
  --overwrite \
  --description "Environment name"

aws ssm put-parameter \
  --name "/humansa/production/ml_server_port" \
  --type "String" \
  --value "6001" \
  --overwrite \
  --description "ML server port"

# Optional: Additional configuration
aws ssm put-parameter \
  --name "/humansa/production/log_level" \
  --type "String" \
  --value "INFO" \
  --overwrite \
  --description "Logging level"

aws ssm put-parameter \
  --name "/humansa/production/max_request_size" \
  --type "String" \
  --value "100MB" \
  --overwrite \
  --description "Maximum request size"

echo "SSM parameters setup complete!"
echo ""
echo "To verify parameters:"
echo "aws ssm get-parameters-by-path --path '/humansa/production' --recursive"
echo ""
echo "Next steps:"
echo "1. Set up GitHub secrets as documented in HUMANSA_ML_DEPLOYMENT_GUIDE.md"
echo "2. Create a release tag to trigger deployment"
echo "3. Monitor the GitHub Actions workflow"