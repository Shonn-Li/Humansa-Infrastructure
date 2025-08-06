#!/bin/bash

# Humansa AWS Resources Setup Script
# This script analyzes existing YouWoAI setup and creates identical resources for Humansa

set -e  # Exit on any error

echo "🚀 Starting Humansa AWS Resources Setup..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if AWS CLI is configured
print_info "Checking AWS CLI configuration..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_error "AWS CLI not configured or credentials invalid"
    echo "Please run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-east-1"  # Hong Kong region for Humansa
print_status "Connected to AWS Account: $ACCOUNT_ID in region: $AWS_REGION"

echo ""
echo "🔍 STEP 1: Analyzing existing YouWoAI setup..."
echo "=============================================="

# Check existing YouWoAI resources
print_info "Finding existing YouWoAI IAM users..."
YOUWOAI_USERS=$(aws iam list-users --query 'Users[?contains(UserName, `youwoai`) || contains(UserName, `terraform`) || contains(UserName, `git`)].UserName' --output text)
if [ ! -z "$YOUWOAI_USERS" ]; then
    print_status "Found YouWoAI users: $YOUWOAI_USERS"
    
    # Get policies for existing terraform user
    for user in $YOUWOAI_USERS; do
        if [[ $user == *"terraform"* ]]; then
            print_info "Checking policies for $user..."
            aws iam list-attached-user-policies --user-name "$user" --query 'AttachedPolicies[].PolicyArn'
        fi
    done
else
    print_warning "No existing YouWoAI users found"
fi

print_info "Finding existing YouWoAI S3 buckets..."
YOUWOAI_BUCKETS=$(aws s3 ls | grep -E "(terraform|tfstate|youwoai)" | awk '{print $3}' || true)
if [ ! -z "$YOUWOAI_BUCKETS" ]; then
    print_status "Found YouWoAI buckets: $YOUWOAI_BUCKETS"
    
    # Check bucket configuration
    for bucket in $YOUWOAI_BUCKETS; do
        if [[ $bucket == *"terraform"* ]] || [[ $bucket == *"tfstate"* ]]; then
            print_info "Checking configuration for bucket: $bucket"
            aws s3api get-bucket-versioning --bucket "$bucket" || true
            aws s3api get-bucket-encryption --bucket "$bucket" || true
        fi
    done
else
    print_warning "No existing YouWoAI terraform buckets found"
fi

print_info "Finding existing YouWoAI DynamoDB tables..."
YOUWOAI_TABLES=$(aws dynamodb list-tables --query 'TableNames[?contains(@, `terraform`) || contains(@, `lock`) || contains(@, `youwoai`)]' --output text)
if [ ! -z "$YOUWOAI_TABLES" ]; then
    print_status "Found YouWoAI tables: $YOUWOAI_TABLES"
    
    # Check table configuration
    for table in $YOUWOAI_TABLES; do
        if [[ $table == *"terraform"* ]] || [[ $table == *"lock"* ]]; then
            print_info "Checking configuration for table: $table"
            aws dynamodb describe-table --table-name "$table" --query 'Table.{KeySchema:KeySchema,ProvisionedThroughput:ProvisionedThroughput}' || true
        fi
    done
else
    print_warning "No existing YouWoAI terraform tables found"
fi

echo ""
echo "🏗️ STEP 2: Creating Humansa resources..."
echo "========================================"

# Generate unique bucket name
TIMESTAMP=$(date +%s)
HUMANSA_BUCKET="humansa-terraform-state-$TIMESTAMP"
HUMANSA_TABLE="humansa-terraform-locks"
HUMANSA_USER="humansa-terraform-user"

# Create S3 bucket for Terraform state
print_info "Creating S3 bucket: $HUMANSA_BUCKET"
if aws s3 mb "s3://$HUMANSA_BUCKET" --region "$AWS_REGION" > /dev/null 2>&1; then
    print_status "S3 bucket created successfully"
    
    # Enable versioning
    print_info "Enabling versioning on S3 bucket..."
    aws s3api put-bucket-versioning \
        --bucket "$HUMANSA_BUCKET" \
        --versioning-configuration Status=Enabled
    print_status "Versioning enabled"
    
    # Block public access
    print_info "Blocking public access on S3 bucket..."
    aws s3api put-public-access-block \
        --bucket "$HUMANSA_BUCKET" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    print_status "Public access blocked"
    
    # Enable encryption
    print_info "Enabling encryption on S3 bucket..."
    aws s3api put-bucket-encryption \
        --bucket "$HUMANSA_BUCKET" \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    print_status "Encryption enabled"
    
else
    print_error "Failed to create S3 bucket"
    exit 1
fi

# Create DynamoDB table for Terraform locking
print_info "Creating DynamoDB table: $HUMANSA_TABLE"
if aws dynamodb create-table \
    --table-name "$HUMANSA_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region "$AWS_REGION" > /dev/null 2>&1; then
    print_status "DynamoDB table created successfully"
    
    # Wait for table to be active
    print_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "$HUMANSA_TABLE" --region "$AWS_REGION"
    print_status "DynamoDB table is active"
else
    print_error "Failed to create DynamoDB table"
    exit 1
fi

# Create IAM user for Terraform
print_info "Creating IAM user: $HUMANSA_USER"
if aws iam create-user --user-name "$HUMANSA_USER" > /dev/null 2>&1; then
    print_status "IAM user created successfully"
    
    # Attach AdministratorAccess policy (same as YouWoAI setup)
    print_info "Attaching AdministratorAccess policy..."
    aws iam attach-user-policy \
        --user-name "$HUMANSA_USER" \
        --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
    print_status "AdministratorAccess policy attached"
    
    # Create access keys
    print_info "Creating access keys..."
    ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$HUMANSA_USER")
    ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
    SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')
    print_status "Access keys created"
    
else
    print_warning "IAM user might already exist or failed to create"
fi

# Create EC2 IAM role (for instances to access SSM)
HUMANSA_EC2_ROLE="humansa-ec2-role"
print_info "Creating EC2 IAM role: $HUMANSA_EC2_ROLE"

# Create trust policy for EC2
cat > /tmp/ec2-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

if aws iam create-role \
    --role-name "$HUMANSA_EC2_ROLE" \
    --assume-role-policy-document file:///tmp/ec2-trust-policy.json > /dev/null 2>&1; then
    print_status "EC2 IAM role created successfully"
    
    # Attach necessary policies
    print_info "Attaching policies to EC2 role..."
    aws iam attach-role-policy \
        --role-name "$HUMANSA_EC2_ROLE" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    
    aws iam attach-role-policy \
        --role-name "$HUMANSA_EC2_ROLE" \
        --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    
    # Create custom policy for SSM parameters
    cat > /tmp/ssm-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath",
                "ssm:PutParameter"
            ],
            "Resource": "arn:aws:ssm:*:$ACCOUNT_ID:parameter/humansa/*"
        }
    ]
}
EOF
    
    aws iam create-policy \
        --policy-name "HumansaSSMPolicy" \
        --policy-document file:///tmp/ssm-policy.json > /dev/null 2>&1 || true
    
    aws iam attach-role-policy \
        --role-name "$HUMANSA_EC2_ROLE" \
        --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/HumansaSSMPolicy" || true
    
    # Create instance profile
    aws iam create-instance-profile --instance-profile-name "$HUMANSA_EC2_ROLE" > /dev/null 2>&1 || true
    aws iam add-role-to-instance-profile \
        --instance-profile-name "$HUMANSA_EC2_ROLE" \
        --role-name "$HUMANSA_EC2_ROLE" > /dev/null 2>&1 || true
    
    print_status "EC2 role configured with necessary policies"
else
    print_warning "EC2 IAM role might already exist or failed to create"
fi

# Clean up temporary files
rm -f /tmp/ec2-trust-policy.json /tmp/ssm-policy.json

echo ""
echo "🎉 SETUP COMPLETE!"
echo "=================="

print_status "Humansa AWS resources created successfully!"
echo ""
echo "📋 RESOURCE SUMMARY:"
echo "===================="
echo "S3 Bucket (Terraform state): $HUMANSA_BUCKET"
echo "DynamoDB Table (Terraform lock): $HUMANSA_TABLE"
echo "IAM User (Terraform): $HUMANSA_USER"
echo "EC2 IAM Role: $HUMANSA_EC2_ROLE"
echo "AWS Region: $AWS_REGION"
echo ""

if [ ! -z "$ACCESS_KEY_ID" ]; then
    echo "🔑 NEW ACCESS KEYS (SAVE THESE!):"
    echo "================================="
    echo "Access Key ID: $ACCESS_KEY_ID"
    echo "Secret Access Key: $SECRET_ACCESS_KEY"
    echo ""
    print_warning "IMPORTANT: Save these credentials securely and delete them from this output!"
fi

echo "📝 NEXT STEPS:"
echo "=============="
echo "1. Update your environments/production/main.tf backend configuration:"
echo "   backend \"s3\" {"
echo "     bucket         = \"$HUMANSA_BUCKET\""
echo "     key            = \"production/terraform.tfstate\""
echo "     region         = \"$AWS_REGION\""
echo "     encrypt        = true"
echo "     dynamodb_table = \"$HUMANSA_TABLE\""
echo "   }"
echo ""
echo "2. Configure terraform.tfvars with your actual values"
echo "3. Run: terraform init"
echo "4. Run: terraform plan -var-file=\"terraform.tfvars\""
echo "5. Run: terraform apply -var-file=\"terraform.tfvars\""
echo ""

print_status "Setup completed successfully! 🚀"