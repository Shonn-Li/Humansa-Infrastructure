#!/bin/bash
set -euo pipefail

# Humansa ML Server Deployment Script
# This script helps deploy the ML server to EC2 instances

echo "🚀 Humansa ML Server Deployment Script"
echo "======================================"

# Configuration
PROJECT_NAME="humansa"
ENVIRONMENT="production"
REGION="ap-east-1"
SSM_PREFIX="/${PROJECT_NAME}/${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "AWS CLI configured"
}

# Function to store SSM parameter
store_ssm_parameter() {
    local name=$1
    local value=$2
    local type=${3:-"String"}
    
    echo -n "Storing parameter ${name}... "
    if aws ssm put-parameter \
        --name "${name}" \
        --value "${value}" \
        --type "${type}" \
        --overwrite \
        --region "${REGION}" &> /dev/null; then
        print_status "done"
    else
        print_error "failed"
        return 1
    fi
}

# Function to get SSM parameter
get_ssm_parameter() {
    local name=$1
    aws ssm get-parameter \
        --name "${name}" \
        --query 'Parameter.Value' \
        --output text \
        --region "${REGION}" 2>/dev/null || echo ""
}

# Main deployment flow
main() {
    echo ""
    print_status "Starting deployment process for Humansa ML Server"
    echo ""
    
    # Check prerequisites
    check_aws_cli
    
    # Check if infrastructure is deployed
    echo -n "Checking if infrastructure is deployed... "
    ALB_DNS=$(get_ssm_parameter "${SSM_PREFIX}/alb_dns_name")
    if [ -z "$ALB_DNS" ]; then
        print_error "Infrastructure not found"
        echo "Please deploy infrastructure first using 'git tag apply-vX.X.X'"
        exit 1
    fi
    print_status "found at ${ALB_DNS}"
    
    # Menu
    echo ""
    echo "What would you like to do?"
    echo "1) Store GitHub PAT for GHCR access"
    echo "2) Store database credentials"
    echo "3) Store API keys"
    echo "4) Deploy ML server (trigger deployment)"
    echo "5) Check deployment status"
    echo "6) View logs"
    echo "0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) store_github_pat ;;
        2) store_database_credentials ;;
        3) store_api_keys ;;
        4) deploy_ml_server ;;
        5) check_deployment_status ;;
        6) view_logs ;;
        0) echo "Exiting..."; exit 0 ;;
        *) print_error "Invalid option"; exit 1 ;;
    esac
}

# Store GitHub PAT
store_github_pat() {
    echo ""
    echo "GitHub Personal Access Token (PAT) Setup"
    echo "======================================="
    echo "You need a GitHub PAT with 'write:packages' permission"
    echo "Create one at: https://github.com/settings/tokens"
    echo ""
    read -sp "Enter your GitHub PAT: " github_pat
    echo ""
    read -p "Enter your GitHub username: " github_username
    
    store_ssm_parameter "${SSM_PREFIX}/github/pat" "${github_pat}" "SecureString"
    store_ssm_parameter "${SSM_PREFIX}/github/username" "${github_username}" "String"
    
    print_status "GitHub credentials stored successfully"
}

# Store database credentials
store_database_credentials() {
    echo ""
    echo "Database Credentials Setup"
    echo "========================="
    
    # Get RDS endpoint from infrastructure
    DB_HOST=$(aws rds describe-db-instances \
        --db-instance-identifier "${PROJECT_NAME}-${ENVIRONMENT}-db" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text \
        --region "${REGION}" 2>/dev/null || echo "")
    
    if [ -z "$DB_HOST" ]; then
        print_warning "Could not find RDS instance. Enter manually:"
        read -p "Database host: " DB_HOST
    else
        print_status "Found RDS endpoint: ${DB_HOST}"
    fi
    
    read -p "Database username [humansa_admin]: " db_username
    db_username=${db_username:-humansa_admin}
    
    read -sp "Database password: " db_password
    echo ""
    
    store_ssm_parameter "${SSM_PREFIX}/db/host" "${DB_HOST}" "String"
    store_ssm_parameter "${SSM_PREFIX}/db/username" "${db_username}" "String"
    store_ssm_parameter "${SSM_PREFIX}/db/password" "${db_password}" "SecureString"
    store_ssm_parameter "${SSM_PREFIX}/db/name" "humansa" "String"
    
    print_status "Database credentials stored successfully"
}

# Store API keys
store_api_keys() {
    echo ""
    echo "API Keys Setup"
    echo "============="
    echo "Enter API keys (press Enter to skip optional ones)"
    echo ""
    
    read -sp "OpenAI API Key (required): " openai_key
    echo ""
    if [ -n "$openai_key" ]; then
        store_ssm_parameter "${SSM_PREFIX}/api/openai_key" "${openai_key}" "SecureString"
    fi
    
    read -sp "Anthropic API Key (optional): " anthropic_key
    echo ""
    if [ -n "$anthropic_key" ]; then
        store_ssm_parameter "${SSM_PREFIX}/api/anthropic_key" "${anthropic_key}" "SecureString"
    fi
    
    read -sp "DeepSeek API Key (optional): " deepseek_key
    echo ""
    if [ -n "$deepseek_key" ]; then
        store_ssm_parameter "${SSM_PREFIX}/api/deepseek_key" "${deepseek_key}" "SecureString"
    fi
    
    print_status "API keys stored successfully"
}

# Deploy ML server
deploy_ml_server() {
    echo ""
    echo "ML Server Deployment"
    echo "==================="
    
    # Check if ML server repo exists
    read -p "Enter your ML server GitHub repository (e.g., username/repo): " ml_repo
    read -p "Enter the version tag to deploy (e.g., v1.0.0): " version_tag
    
    # Store the image tag
    store_ssm_parameter "${SSM_PREFIX}/ml_server_image_tag" "${version_tag}" "String"
    store_ssm_parameter "${SSM_PREFIX}/ml_server_repo" "ghcr.io/${ml_repo}" "String"
    
    # Get ASG name
    ASG_NAME=$(get_ssm_parameter "${SSM_PREFIX}/asg_name")
    
    if [ -z "$ASG_NAME" ]; then
        print_error "Auto Scaling Group not found"
        exit 1
    fi
    
    echo ""
    print_status "Triggering instance refresh for ${ASG_NAME}..."
    
    # Trigger instance refresh
    if aws autoscaling start-instance-refresh \
        --auto-scaling-group-name "${ASG_NAME}" \
        --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 300}' \
        --region "${REGION}"; then
        print_status "Instance refresh started successfully"
        echo ""
        echo "Deployment initiated. Instances will be updated one by one."
        echo "This process typically takes 10-15 minutes."
        echo "Run option 5 to check deployment status."
    else
        print_error "Failed to start instance refresh"
    fi
}

# Check deployment status
check_deployment_status() {
    echo ""
    echo "Deployment Status"
    echo "================"
    
    # Get ASG name
    ASG_NAME=$(get_ssm_parameter "${SSM_PREFIX}/asg_name")
    
    if [ -z "$ASG_NAME" ]; then
        print_error "Auto Scaling Group not found"
        return
    fi
    
    # Check instance refresh status
    REFRESH_STATUS=$(aws autoscaling describe-instance-refreshes \
        --auto-scaling-group-name "${ASG_NAME}" \
        --query 'InstanceRefreshes[0].Status' \
        --output text \
        --region "${REGION}" 2>/dev/null || echo "None")
    
    echo "Instance refresh status: ${REFRESH_STATUS}"
    
    # Get instance health
    echo ""
    echo "Instance Health:"
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${ASG_NAME}" \
        --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
        --output table \
        --region "${REGION}"
    
    # Check target health
    TG_ARN=$(get_ssm_parameter "${SSM_PREFIX}/ml_tg_arn")
    if [ -n "$TG_ARN" ]; then
        echo ""
        echo "Target Group Health:"
        aws elbv2 describe-target-health \
            --target-group-arn "${TG_ARN}" \
            --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
            --output table \
            --region "${REGION}"
    fi
}

# View logs
view_logs() {
    echo ""
    echo "CloudWatch Logs"
    echo "=============="
    
    # List log groups
    echo "Available log groups:"
    aws logs describe-log-groups \
        --log-group-name-prefix "/aws/ec2/humansa-ml" \
        --query 'logGroups[*].logGroupName' \
        --output text \
        --region "${REGION}"
    
    echo ""
    read -p "Enter instance ID to view logs (or 'all' for all instances): " instance_id
    
    if [ "$instance_id" = "all" ]; then
        LOG_GROUP="/aws/ec2/humansa-ml/${ENVIRONMENT}"
    else
        LOG_GROUP="/aws/ec2/humansa-ml/${ENVIRONMENT}"
        LOG_STREAM="${instance_id}"
    fi
    
    echo ""
    echo "Recent logs:"
    if [ -n "${LOG_STREAM:-}" ]; then
        aws logs tail "${LOG_GROUP}" \
            --log-stream-names "${LOG_STREAM}" \
            --region "${REGION}" \
            --follow
    else
        aws logs tail "${LOG_GROUP}" \
            --region "${REGION}" \
            --follow
    fi
}

# Run main function
main "$@"