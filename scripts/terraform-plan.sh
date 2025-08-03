#!/bin/bash
set -euo pipefail

# Humansa Infrastructure - Terraform Plan Script
echo "🔍 Humansa Infrastructure - Terraform Plan"
echo "========================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars not found!${NC}"
    echo "Please copy terraform.tfvars.example and fill in your values:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}❌ AWS credentials not configured!${NC}"
    echo "Please run: aws configure"
    exit 1
fi

# Get current AWS account
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="${AWS_REGION:-ap-east-1}"

echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ Region: ${REGION}${NC}"
echo ""

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
fi

# Create plan file
PLAN_FILE="tfplan-$(date +%Y%m%d-%H%M%S)"

echo -e "${YELLOW}Running Terraform plan...${NC}"
echo "Plan will be saved to: ${PLAN_FILE}"
echo ""

# Run terraform plan
if terraform plan -var-file="terraform.tfvars" -out="${PLAN_FILE}"; then
    echo ""
    echo -e "${GREEN}✅ Plan completed successfully!${NC}"
    echo ""
    echo "Review the plan above carefully, then:"
    echo "  1. To apply this plan: ./terraform-apply.sh ${PLAN_FILE}"
    echo "  2. To create a new plan: ./terraform-plan.sh"
    echo ""
    
    # Show cost estimate reminder
    echo -e "${YELLOW}💰 Estimated Monthly Costs:${NC}"
    echo "  - EC2 (2x t3.medium): ~\$67/month"
    echo "  - RDS (db.t3.medium): ~\$85/month"
    echo "  - ALB: ~\$30/month"
    echo "  - NAT Gateways (2x): ~\$85/month"
    echo "  - Redis: ~\$15/month"
    echo "  - Total: ~\$282/month (without optimizations)"
    echo ""
    echo -e "${YELLOW}💡 Cost optimization available: Save \$143/month${NC}"
    echo "  Run infrastructure review for details"
else
    echo ""
    echo -e "${RED}❌ Plan failed!${NC}"
    echo "Please check the errors above"
    exit 1
fi