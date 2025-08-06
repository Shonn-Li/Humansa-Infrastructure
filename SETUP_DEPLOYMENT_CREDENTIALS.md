# Setting Up Deployment Credentials for Humansa ML Server

## Overview

You need to create separate credentials for:
1. **AWS IAM User** for GitHub Actions deployment (separate from your admin credentials)
2. **GitHub PAT** for container registry access (can be the same or different from infrastructure PAT)

## 1. Create AWS IAM User for Deployment

### Step 1: Create the IAM User

```bash
# Create IAM user for GitHub Actions deployment
aws iam create-user --user-name humansa-ml-deploy-user
```

### Step 2: Create and Attach IAM Policy

Create a file `humansa-deploy-policy.json`:

```json
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
        "arn:aws:ssm:ap-east-1:992382528744:parameter/humansa/production/*"
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
          "kms:ViaService": "ssm.ap-east-1.amazonaws.com"
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
```

Apply the policy:

```bash
# Create the policy
aws iam create-policy \
  --policy-name humansa-ml-deploy-policy \
  --policy-document file://humansa-deploy-policy.json \
  --description "Policy for Humansa ML Server deployment via GitHub Actions"

# Get the policy ARN (it will be shown in the output above)
# Example: arn:aws:iam::992382528744:policy/humansa-ml-deploy-policy

# Attach the policy to the user
aws iam attach-user-policy \
  --user-name humansa-ml-deploy-user \
  --policy-arn arn:aws:iam::992382528744:policy/humansa-ml-deploy-policy
```

### Step 3: Create Access Keys

```bash
# Create access key for the deployment user
aws iam create-access-key --user-name humansa-ml-deploy-user

# This will output:
# {
#     "AccessKey": {
#         "UserName": "humansa-ml-deploy-user",
#         "AccessKeyId": "AKIA...",
#         "Status": "Active",
#         "SecretAccessKey": "...",
#         "CreateDate": "2024-..."
#     }
# }
```

**IMPORTANT**: Save these credentials securely! You'll need:
- `AccessKeyId` → Will be `AWS_DEPLOY_ACCESS_KEY` in GitHub Secrets
- `SecretAccessKey` → Will be `AWS_DEPLOY_SECRET_ACCESS_KEY` in GitHub Secrets

## 2. GitHub PAT for Container Registry

### Option A: Use the Same GHCR_PAT

If you already created a GitHub PAT for infrastructure deployment with `write:packages` permission, you can use the same one. This is the simplest approach.

### Option B: Create a Separate PAT (Recommended for Security)

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name it: "Humansa ML Server GHCR Access"
4. Set expiration as needed
5. Select permissions:
   - ✅ `write:packages` - Upload packages to GitHub Package Registry
   - ✅ `read:packages` - Download packages from GitHub Package Registry
   - ✅ `delete:packages` - (optional) Delete old versions
6. Click "Generate token"
7. Copy and save the token

## 3. AWS Credentials for ML Server Runtime

The ML server itself needs AWS credentials to access services like S3, CloudWatch, etc. You have two options:

### Option A: Use IAM Role (Recommended)

The EC2 instances already have an IAM role attached that allows access to SSM and CloudWatch. You can extend this role with additional permissions if needed.

### Option B: Create Separate Access Keys

If your ML server needs to access services that the IAM role doesn't cover:

```bash
# Create IAM user for ML server runtime
aws iam create-user --user-name humansa-ml-runtime-user

# Attach necessary policies (example for S3 access)
aws iam attach-user-policy \
  --user-name humansa-ml-runtime-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Create access key
aws iam create-access-key --user-name humansa-ml-runtime-user
```

These would be:
- `AccessKeyId` → `AWS_ACCESS_KEY` in GitHub Secrets
- `SecretAccessKey` → `AWS_SECRET_ACCESS_KEY` in GitHub Secrets

## 4. Summary of GitHub Secrets to Add

In your Humansa ML Server GitHub repository, add these secrets:

```yaml
# Deployment Credentials (from Step 1)
AWS_DEPLOY_ACCESS_KEY: AKIA...  # From humansa-ml-deploy-user
AWS_DEPLOY_SECRET_ACCESS_KEY: ... # From humansa-ml-deploy-user
AWS_REGION: ap-east-1
SSH_PRIVATE_KEY: |  # Content of ~/.ssh/humansa-infrastructure
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----

# Container Registry (from Step 2)
GHCR_PAT: ghp_...  # Your GitHub PAT with packages permission

# API Keys for ML Server
OPENAI_API_KEY: sk-...
ANTHROPIC_API_KEY: sk-ant-...

# AWS Runtime Credentials (if not using IAM role)
AWS_ACCESS_KEY: AKIA...  # Optional, from humansa-ml-runtime-user
AWS_SECRET_ACCESS_KEY: ... # Optional, from humansa-ml-runtime-user

# Optional API Keys
DEEPSEEK_API_KEY: ...
GOOGLE_API_KEY: ...
XAI_API_KEY: ...
AZURE_INFERENCE_ENDPOINT: ...
AZURE_INFERENCE_CREDENTIAL: ...
WEBSHARE_PROXY_USERNAME: ...
WEBSHARE_PROXY_PASSWORD: ...
```

## 5. Update SSM Parameter with GitHub PAT

After creating the PAT, update the SSM parameter:

```bash
aws ssm put-parameter \
  --name "/humansa/production/github_pat" \
  --value "ghp_YOUR_ACTUAL_PAT_HERE" \
  --type "SecureString" \
  --overwrite \
  --region ap-east-1
```

## 6. Test Deployment Access

Test that the deployment user can access necessary resources:

```bash
# Configure AWS CLI with deployment credentials
aws configure --profile humansa-deploy
# Enter the AWS_DEPLOY_ACCESS_KEY and AWS_DEPLOY_SECRET_ACCESS_KEY

# Test SSM access
aws ssm get-parameter \
  --name "/humansa/production/ml_tg_arn" \
  --profile humansa-deploy \
  --region ap-east-1

# Test EC2 describe
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=humansa" \
  --profile humansa-deploy \
  --region ap-east-1
```

## Security Best Practices

1. **Rotate credentials regularly** - Set calendar reminders
2. **Use least privilege** - Only grant necessary permissions
3. **Never commit credentials** - Always use GitHub Secrets
4. **Monitor usage** - Enable CloudTrail for the deployment user
5. **Use separate credentials** - Don't reuse your admin credentials

## Next Steps

After setting up all credentials:

1. Add them to your ML Server GitHub repository secrets
2. Copy the deployment files from `humansa-infrastructure/`:
   - `.github/workflows/release.yml`
   - `ml-playbook.yml`
   - `inventory_aws_ec2.yml`
3. Create your Dockerfile and push code
4. Tag a release: `git tag release-1.0.0 && git push origin release-1.0.0`
5. Watch the deployment in GitHub Actions!