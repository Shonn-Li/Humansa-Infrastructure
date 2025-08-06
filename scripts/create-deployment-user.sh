#!/bin/bash
set -euo pipefail

# Script to create AWS IAM user for Humansa ML deployment
# This creates a limited-permission user for GitHub Actions

echo "🔐 Creating AWS IAM User for Humansa ML Deployment"
echo "=================================================="
echo ""

# Configuration
USER_NAME="humansa-ml-deploy-user"
POLICY_NAME="humansa-ml-deploy-policy"
REGION="ap-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Step 1: Create IAM User
echo "Step 1: Creating IAM user '$USER_NAME'..."
if aws iam create-user --user-name $USER_NAME 2>/dev/null; then
    print_success "User created successfully"
else
    print_warning "User already exists or error occurred"
fi

# Step 2: Create IAM Policy
echo ""
echo "Step 2: Creating IAM policy..."

# Create policy document
cat > /tmp/humansa-deploy-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeTags",
        "ec2:DescribeInstanceAttribute"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:PutParameter"
      ],
      "Resource": [
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter/humansa/production/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "ssm.${REGION}.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create the policy
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
if aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file:///tmp/humansa-deploy-policy.json \
    --description "Policy for Humansa ML Server deployment via GitHub Actions" 2>/dev/null; then
    print_success "Policy created successfully"
else
    print_warning "Policy already exists or error occurred"
fi

# Step 3: Attach policy to user
echo ""
echo "Step 3: Attaching policy to user..."
if aws iam attach-user-policy \
    --user-name $USER_NAME \
    --policy-arn $POLICY_ARN; then
    print_success "Policy attached successfully"
else
    print_error "Failed to attach policy"
fi

# Step 4: Create access key
echo ""
echo "Step 4: Creating access key..."
echo ""

# Check if user already has access keys
EXISTING_KEYS=$(aws iam list-access-keys --user-name $USER_NAME --query 'AccessKeyMetadata[].AccessKeyId' --output text)
if [ -n "$EXISTING_KEYS" ]; then
    print_warning "User already has access keys: $EXISTING_KEYS"
    read -p "Create another access key? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping access key creation"
        exit 0
    fi
fi

# Create access key
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name $USER_NAME)

# Extract credentials
ACCESS_KEY_ID=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.SecretAccessKey')

# Clean up
rm -f /tmp/humansa-deploy-policy.json

# Display results
echo ""
echo "=========================================="
echo "✅ IAM User Setup Complete!"
echo "=========================================="
echo ""
echo "Save these credentials in your GitHub Secrets:"
echo ""
echo "AWS_DEPLOY_ACCESS_KEY=$ACCESS_KEY_ID"
echo "AWS_DEPLOY_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY"
echo ""
print_warning "IMPORTANT: Save these credentials now! The secret key cannot be retrieved again."
echo ""
echo "Next steps:"
echo "1. Go to your ML Server GitHub repo → Settings → Secrets"
echo "2. Add the AWS_DEPLOY_ACCESS_KEY and AWS_DEPLOY_SECRET_ACCESS_KEY"
echo "3. Add AWS_REGION=ap-east-1"
echo "4. Add your SSH_PRIVATE_KEY content"
echo ""

# Optional: Test the credentials
read -p "Would you like to test these credentials? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Testing credentials..."
    
    # Test SSM access
    if AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY \
       aws ssm get-parameter --name "/humansa/production/vpc_id" --region $REGION &>/dev/null; then
        print_success "SSM parameter access works!"
    else
        print_error "SSM parameter access failed"
    fi
    
    # Test EC2 describe
    if AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY \
       aws ec2 describe-instances --region $REGION &>/dev/null; then
        print_success "EC2 describe access works!"
    else
        print_error "EC2 describe access failed"
    fi
fi

echo ""
echo "✨ Done!"