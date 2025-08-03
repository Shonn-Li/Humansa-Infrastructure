#!/bin/bash
set -euo pipefail

# Humansa Secrets Setup Script
# This script sets up all required secrets that can't be managed by Terraform

echo "🔐 Humansa Secrets Setup"
echo "======================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}❌ AWS CLI is not configured or you don't have valid credentials${NC}"
    echo "Please run: aws configure"
    exit 1
fi

# Get current AWS account and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="${AWS_REGION:-ap-east-1}"
ENVIRONMENT="${ENVIRONMENT:-production}"

echo -e "${GREEN}✓ Using AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ Region: ${REGION}${NC}"
echo -e "${GREEN}✓ Environment: ${ENVIRONMENT}${NC}"
echo ""

# Function to create or update parameter
create_parameter() {
    local name=$1
    local value=$2
    local type=${3:-SecureString}
    local description=${4:-""}
    
    echo -n "Creating parameter ${name}... "
    
    if aws ssm put-parameter \
        --name "$name" \
        --value "$value" \
        --type "$type" \
        --description "$description" \
        --overwrite \
        --region "$REGION" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# API Keys and Secrets (not managed by Terraform)
echo -e "${YELLOW}Setting up API secrets...${NC}"

# OpenAI API Key
read -sp "Enter OpenAI API Key: " OPENAI_API_KEY
echo ""
create_parameter "/humansa/${ENVIRONMENT}/api/openai_key" "$OPENAI_API_KEY" "SecureString" "OpenAI API Key"

# Anthropic API Key (if using Claude)
read -sp "Enter Anthropic API Key (press Enter to skip): " ANTHROPIC_API_KEY
echo ""
if [ -n "$ANTHROPIC_API_KEY" ]; then
    create_parameter "/humansa/${ENVIRONMENT}/api/anthropic_key" "$ANTHROPIC_API_KEY" "SecureString" "Anthropic API Key"
fi

# DeepSeek API Key (if using)
read -sp "Enter DeepSeek API Key (press Enter to skip): " DEEPSEEK_API_KEY
echo ""
if [ -n "$DEEPSEEK_API_KEY" ]; then
    create_parameter "/humansa/${ENVIRONMENT}/api/deepseek_key" "$DEEPSEEK_API_KEY" "SecureString" "DeepSeek API Key"
fi

# Google Gemini API Key (if using)
read -sp "Enter Google Gemini API Key (press Enter to skip): " GEMINI_API_KEY
echo ""
if [ -n "$GEMINI_API_KEY" ]; then
    create_parameter "/humansa/${ENVIRONMENT}/api/gemini_key" "$GEMINI_API_KEY" "SecureString" "Google Gemini API Key"
fi

echo ""
echo -e "${YELLOW}Setting up authentication secrets...${NC}"

# JWT Secret for API authentication
echo "Generating JWT secret..."
JWT_SECRET=$(openssl rand -base64 32)
create_parameter "/humansa/${ENVIRONMENT}/auth/jwt_secret" "$JWT_SECRET" "SecureString" "JWT signing secret"

# Session Secret
echo "Generating session secret..."
SESSION_SECRET=$(openssl rand -base64 32)
create_parameter "/humansa/${ENVIRONMENT}/auth/session_secret" "$SESSION_SECRET" "SecureString" "Session encryption secret"

echo ""
echo -e "${YELLOW}Setting up optional integrations...${NC}"

# Sentry DSN (optional)
read -p "Enter Sentry DSN (press Enter to skip): " SENTRY_DSN
if [ -n "$SENTRY_DSN" ]; then
    create_parameter "/humansa/${ENVIRONMENT}/monitoring/sentry_dsn" "$SENTRY_DSN" "String" "Sentry error tracking DSN"
fi

# Slack Webhook (optional)
read -sp "Enter Slack Webhook URL (press Enter to skip): " SLACK_WEBHOOK
echo ""
if [ -n "$SLACK_WEBHOOK" ]; then
    create_parameter "/humansa/${ENVIRONMENT}/notifications/slack_webhook" "$SLACK_WEBHOOK" "SecureString" "Slack webhook for notifications"
fi

echo ""
echo -e "${YELLOW}Setting up environment configuration...${NC}"

# Environment-specific configuration
create_parameter "/humansa/${ENVIRONMENT}/config/environment" "$ENVIRONMENT" "String" "Environment name"
create_parameter "/humansa/${ENVIRONMENT}/config/region" "$REGION" "String" "AWS region"
create_parameter "/humansa/${ENVIRONMENT}/config/log_level" "INFO" "String" "Application log level"

echo ""
echo -e "${GREEN}✅ Secret setup complete!${NC}"
echo ""
echo "Summary of parameters created:"
echo "- API Keys: /humansa/${ENVIRONMENT}/api/*"
echo "- Auth Secrets: /humansa/${ENVIRONMENT}/auth/*"
echo "- Config: /humansa/${ENVIRONMENT}/config/*"
echo "- Database: /humansa/${ENVIRONMENT}/db/* (created by Terraform)"
echo "- Redis: /humansa/${ENVIRONMENT}/redis/* (created by Terraform)"
echo ""
echo -e "${YELLOW}Note: Database and Redis credentials are managed by Terraform${NC}"
echo ""
echo "To view a parameter:"
echo "  aws ssm get-parameter --name '/humansa/${ENVIRONMENT}/api/openai_key' --with-decryption"
echo ""
echo "To list all parameters:"
echo "  aws ssm describe-parameters --parameter-filters 'Key=Name,Values=/humansa/${ENVIRONMENT}'"