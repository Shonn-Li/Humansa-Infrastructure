#!/bin/bash

# Humansa Terraform Apply Script
# Based on YouWoAI's GitHub Actions workflow

set -e

echo "🚀 Starting Humansa Terraform Apply..."
echo "====================================="

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

# Check if version is provided
if [ -z "$1" ]; then
    print_error "Version is required"
    echo "Usage: $0 <version>"
    echo "Example: $0 20240103-143000"
    echo ""
    echo "Available plans:"
    aws s3 ls s3://humansa-terraform-state/plans/ | grep "plan-" | awk '{print $4}' | sed 's/plan-//g' | sed 's/.tfplan//g'
    exit 1
fi

VERSION=$1

# Check if we're in the right directory
if [ ! -f "environments/production/main.tf" ]; then
    print_error "Please run this script from the humansa-infrastructure root directory"
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

# Download plan from S3
print_info "Downloading plan from S3..."
if ! aws s3 cp s3://humansa-terraform-state/plans/plan-${VERSION}.tfplan terraform.tfplan; then
    print_error "Failed to download plan-${VERSION}.tfplan from S3"
    echo ""
    echo "Available plans:"
    aws s3 ls s3://humansa-terraform-state/plans/ | grep "plan-" | awk '{print $4}' | sed 's/plan-//g' | sed 's/.tfplan//g'
    exit 1
fi
print_status "Downloaded plan-${VERSION}.tfplan from S3"

# Show plan before applying
echo ""
echo "📋 PLAN TO APPLY:"
echo "================="
terraform show terraform.tfplan
echo ""

# Confirmation prompt
print_warning "This will apply the above changes to your AWS infrastructure!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Apply cancelled by user"
    rm -f terraform.tfplan
    exit 0
fi

# Apply the plan
print_info "Applying Terraform plan..."
echo ""
if terraform apply -auto-approve terraform.tfplan; then
    print_status "Terraform apply completed successfully! 🎉"
else
    print_error "Terraform apply failed"
    rm -f terraform.tfplan
    exit 1
fi

# Clean up
rm -f terraform.tfplan

echo ""
echo "📊 INFRASTRUCTURE OUTPUTS:"
echo "=========================="
terraform output

echo ""
print_status "Infrastructure deployment completed successfully! 🚀"
echo ""
echo "📝 NEXT STEPS:"
echo "=============="
echo "1. Verify your infrastructure in AWS Console"
echo "2. Test your endpoints:"
echo "   - Health check: curl https://humansa.youwo.ai/health"
echo "   - API test: curl -H 'Authorization: Bearer YOUR_TOKEN' https://humansa.youwo.ai/api/test"
echo "3. Monitor CloudWatch logs and metrics"
echo "4. Set up monitoring dashboards if needed"
echo ""
print_info "Infrastructure is ready for your Humansa ML API! 🎯"