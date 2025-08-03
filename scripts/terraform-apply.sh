#!/bin/bash
set -euo pipefail

# Humansa Infrastructure - Terraform Apply Script
echo "🚀 Humansa Infrastructure - Terraform Apply"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if plan file provided
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ No plan file provided!${NC}"
    echo "Usage: ./terraform-apply.sh <plan-file>"
    echo ""
    echo "First run: ./terraform-plan.sh"
    exit 1
fi

PLAN_FILE=$1

# Check if plan file exists
if [ ! -f "$PLAN_FILE" ]; then
    echo -e "${RED}❌ Plan file not found: $PLAN_FILE${NC}"
    echo "Please run ./terraform-plan.sh first"
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
echo -e "${GREEN}✓ Plan file: ${PLAN_FILE}${NC}"
echo ""

# Confirmation
echo -e "${YELLOW}⚠️  WARNING: This will create real AWS resources and incur costs!${NC}"
echo ""
echo "Estimated daily cost: ~\$9.40/day (\$282/month)"
echo ""
read -p "Are you sure you want to apply this plan? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Apply cancelled."
    exit 0
fi

# Apply the plan
echo -e "${YELLOW}Applying Terraform plan...${NC}"
if terraform apply "$PLAN_FILE"; then
    echo ""
    echo -e "${GREEN}✅ Infrastructure deployed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run setup-secrets.sh to configure API keys:"
    echo "     ./setup-secrets.sh"
    echo ""
    echo "  2. Get important outputs:"
    echo "     terraform output -json > outputs.json"
    echo ""
    echo "  3. Test the API endpoint:"
    echo "     curl -I https://humansa.youwo.ai/health"
    echo ""
    echo "  4. Monitor costs in AWS Cost Explorer"
    echo ""
    echo -e "${YELLOW}📊 Resources created:${NC}"
    echo "  - ALB URL: $(terraform output -raw alb_dns_name 2>/dev/null || echo 'Run terraform output')"
    echo "  - API Endpoint: https://humansa.youwo.ai"
    echo ""
    
    # Save outputs to file
    echo "Saving outputs to outputs.json..."
    terraform output -json > outputs.json
    
else
    echo ""
    echo -e "${RED}❌ Apply failed!${NC}"
    echo "Check the errors above and try again"
    exit 1
fi