#!/bin/bash
set -euo pipefail

# Humansa Infrastructure - Terraform Destroy Script
echo "💥 Humansa Infrastructure - Terraform Destroy"
echo "==========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# Show current resources
echo -e "${YELLOW}Current resources that will be destroyed:${NC}"
terraform state list 2>/dev/null | head -20 || echo "No resources found"
echo ""

# Double confirmation
echo -e "${RED}⚠️  DANGER: This will DESTROY all infrastructure!${NC}"
echo "This action cannot be undone."
echo ""
read -p "Type 'destroy-humansa' to confirm: " -r
echo

if [[ ! $REPLY == "destroy-humansa" ]]; then
    echo "Destroy cancelled."
    exit 0
fi

# Create destroy plan
echo -e "${YELLOW}Creating destroy plan...${NC}"
DESTROY_PLAN="destroy-plan-$(date +%Y%m%d-%H%M%S)"

if terraform plan -destroy -var-file="terraform.tfvars" -out="$DESTROY_PLAN"; then
    echo ""
    echo -e "${YELLOW}Review the destroy plan above.${NC}"
    read -p "Proceed with destroy? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Destroy cancelled."
        exit 0
    fi
    
    # Execute destroy
    echo -e "${RED}Destroying infrastructure...${NC}"
    if terraform apply "$DESTROY_PLAN"; then
        echo ""
        echo -e "${GREEN}✅ Infrastructure destroyed successfully!${NC}"
        echo ""
        echo "Cleanup tasks:"
        echo "  1. Remove any Route53 records manually if needed"
        echo "  2. Check AWS Console for any remaining resources"
        echo "  3. Remove local state files: rm -rf .terraform terraform.tfstate*"
    else
        echo ""
        echo -e "${RED}❌ Destroy failed!${NC}"
        echo "Some resources may have been partially destroyed."
        echo "Check AWS Console and try again."
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to create destroy plan${NC}"
    exit 1
fi