#!/bin/bash

# Humansa Terraform Plan Script
# Based on YouWoAI's GitHub Actions workflow

set -e

echo "🚀 Starting Humansa Terraform Plan..."
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "environments/production/main.tf" ]; then
    print_error "Please run this script from the humansa-infrastructure root directory"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "environments/production/terraform.tfvars" ]; then
    print_error "terraform.tfvars not found in environments/production/"
    print_info "Please create it from terraform.tfvars.example and fill in your values"
    exit 1
fi

# Check AWS CLI configuration
print_info "Checking AWS CLI configuration..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_error "AWS CLI not configured or credentials invalid"
    echo "Please run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
print_status "Connected to AWS Account: $ACCOUNT_ID in region: $AWS_REGION"

# Navigate to production environment
cd environments/production

# Initialize Terraform
print_info "Initializing Terraform..."
if ! terraform init; then
    print_error "Terraform init failed"
    exit 1
fi
print_status "Terraform initialized successfully"

# Format check
print_info "Checking Terraform formatting..."
terraform fmt -check
print_status "Terraform formatting is correct"

# Validate configuration
print_info "Validating Terraform configuration..."
if ! terraform validate -no-color; then
    print_error "Terraform validation failed"
    exit 1
fi
print_status "Terraform configuration is valid"

# Get version (current timestamp if not provided)
if [ -z "$1" ]; then
    VERSION=$(date +%Y%m%d-%H%M%S)
    print_info "No version provided, using timestamp: $VERSION"
else
    VERSION=$1
    print_info "Using provided version: $VERSION"
fi

# Create plans directory if it doesn't exist
aws s3api head-object --bucket humansa-terraform-state --key plans/ > /dev/null 2>&1 || {
    print_info "Creating plans directory in S3..."
    aws s3api put-object --bucket humansa-terraform-state --key plans/
}

# Run Terraform Plan
print_info "Running Terraform plan..."
if ! terraform plan -var-file="terraform.tfvars" -out=terraform.tfplan; then
    print_error "Terraform plan failed"
    exit 1
fi
print_status "Terraform plan completed successfully"

# Upload plan to S3 (following YouWoAI pattern)
print_info "Uploading plan to S3..."
if aws s3 cp terraform.tfplan s3://humansa-terraform-state/plans/plan-${VERSION}.tfplan; then
    print_status "Plan uploaded to S3 as plan-${VERSION}.tfplan"
else
    print_error "Failed to upload plan to S3"
    exit 1
fi

# Generate and upload plan summary
print_info "Generating plan summary..."
terraform show -no-color terraform.tfplan > plan-summary.txt
if aws s3 cp plan-summary.txt s3://humansa-terraform-state/plans/plan-${VERSION}-summary.txt; then
    print_status "Plan summary uploaded to S3"
else
    print_warning "Failed to upload plan summary (not critical)"
fi

# Show plan summary
echo ""
echo "📋 PLAN SUMMARY:"
echo "================"
terraform show -no-color terraform.tfplan | head -50
echo ""
print_info "Full plan summary available at: s3://humansa-terraform-state/plans/plan-${VERSION}-summary.txt"

# Clean up local files
rm -f terraform.tfplan plan-summary.txt

echo ""
print_status "Plan completed successfully! 🎉"
echo ""
echo "📝 NEXT STEPS:"
echo "=============="
echo "1. Review the plan output above"
echo "2. Check the detailed summary in S3 if needed"
echo "3. If everything looks good, run:"
echo "   ./scripts/terraform-apply.sh ${VERSION}"
echo ""
print_warning "Remember: Always review plans carefully before applying!"