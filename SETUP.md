# Humansa Infrastructure Setup Guide (SETUP)

## Prerequisites

### Required Tools
- AWS CLI configured with admin access
- Terraform >= 1.0
- Git
- GitHub account with repository access

### Required AWS Resources
- AWS Account with admin permissions
- S3 bucket for Terraform state (will be created)
- DynamoDB table for state locking (will be created)

## Step-by-Step Setup Instructions

### Step 1: Create S3 Backend for Terraform State

**Why**: Terraform needs remote state storage for team collaboration and state locking.

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket humansa-terraform-state \
  --region ap-east-1 \
  --create-bucket-configuration LocationConstraint=ap-east-1

# Enable versioning for state protection
aws s3api put-bucket-versioning \
  --bucket humansa-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name humansa-terraform-state-locking \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region ap-east-1
```

### Step 2: Create OIDC Identity Provider in AWS (✅ COMPLETED)

**Why**: Enables GitHub Actions to authenticate without storing AWS credentials.

**Status**: Already exists - Created on 2024-04-11

```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers
# Output: arn:aws:iam::992382528744:oidc-provider/token.actions.githubusercontent.com
```

### Step 3: Create IAM Role for GitHub Actions (✅ COMPLETED)

**Why**: This role will be assumed by GitHub Actions for deployments.

**Status**: Created successfully as `humansa-github-actions-role`

**Role ARN**: `arn:aws:iam::992382528744:role/humansa-github-actions-role`

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::992382528744:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Shonn-Li/humansa-infrastructure:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

**Attached Policies**: AdministratorAccess

### Step 4: Generate SSH Key Pair for EC2 Access

**Why**: Allows secure SSH access to EC2 instances for debugging and management.

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/humansa-infrastructure -C "humansa-infrastructure"

# Display the public key (you'll need this for GitHub secrets)
cat ~/.ssh/humansa-infrastructure.pub
```

**Important**: 
- Keep the private key (`~/.ssh/humansa-infrastructure`) secure
- You'll add the public key to GitHub secrets
- This matches YouWoAI's approach (they store `youwoai-key.pub` in their repo)

### Step 5: Create GitHub Repository

**Why**: Version control and automated deployment trigger.

```bash
# Create new repository on GitHub
gh repo create humansa-infrastructure --private

# Initialize local repository
cd humansa-infrastructure
git init
git add .
git commit -m "Initial infrastructure setup"
git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/humansa-infrastructure.git
git push -u origin main
```

### Step 6: Configure GitHub Secrets

**Why**: Securely store configuration for GitHub Actions.

Go to GitHub repository settings > Secrets and variables > Actions, then add:

1. **AWS_ROLE**: `arn:aws:iam::992382528744:role/humansa-github-actions-role`
2. **AWS_REGION**: `ap-east-1`
3. **DB_USERNAME**: `humansa_admin`
4. **DB_PASSWORD**: `[your-secure-database-password]`
5. **ROUTE53_ZONE_ID**: `[your-route53-zone-id-for-youwo.ai]`
6. **GHCR_PAT**: `[your-github-personal-access-token]`
7. **SSH_PUBLIC_KEY**: `[paste-entire-public-key-from-step-4]`

**Example SSH_PUBLIC_KEY format**:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... humansa-infrastructure
```

**Note**: Paste the ENTIRE content from `cat ~/.ssh/humansa-infrastructure.pub` including the ssh-rsa prefix and comment suffix.

### Step 7: Create GitHub Actions Workflows

**Why**: Automated deployment pipeline.

Create `.github/workflows/terraform-plan.yml`:
```yaml
name: "Terraform Plan"

on:
  push:
    tags:
      - "plan-*"

permissions:
  id-token: write
  contents: read

env:
  TF_LOG: "INFO"
  AWS_REGION: ${{ secrets.AWS_REGION }}
  TF_VAR_aws_region: ${{ secrets.AWS_REGION }}
  TF_VAR_db_username: ${{ secrets.DB_USERNAME }}
  TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
  TF_VAR_route53_zone_id: ${{ secrets.ROUTE53_ZONE_ID }}
  TF_VAR_ghcr_pat: ${{ secrets.GHCR_PAT }}

jobs:
  plan:
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash
        working-directory: environments/production
    steps:
      - name: Git checkout
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          role-to-assume: ${{ secrets.AWS_ROLE }}
          aws-region: ${{ secrets.AWS_REGION }}
          role-session-name: GitHub-OIDC-TERRAFORM

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: "1.8.1"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=terraform.tfplan

      - name: Upload Plan to S3
        run: |
          VERSION=$(echo ${{ github.ref }} | sed -e 's|refs/tags/plan-||')
          aws s3 cp terraform.tfplan s3://humansa-terraform-state/plans/plan-${VERSION}.tfplan
```

Create `.github/workflows/terraform-apply.yml`:
```yaml
name: "Terraform Apply"

on:
  push:
    tags:
      - "apply-*"

permissions:
  id-token: write
  contents: read

env:
  TF_LOG: "INFO"
  AWS_REGION: ${{ secrets.AWS_REGION }}

jobs:
  apply:
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash
        working-directory: environments/production
    steps:
      - name: Git checkout
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          role-to-assume: ${{ secrets.AWS_ROLE }}
          aws-region: ${{ secrets.AWS_REGION }}
          role-session-name: GitHub-OIDC-TERRAFORM

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: "1.8.1"

      - name: Extract version number
        id: get_version
        run: echo "version=$(echo ${{ github.ref }} | sed -e 's|refs/tags/apply-||')" >> $GITHUB_ENV

      - name: Download Plan from S3
        run: |
          aws s3 cp s3://humansa-terraform-state/plans/plan-${{ env.version }}.tfplan terraform.tfplan

      - name: Terraform Apply
        run: terraform apply -auto-approve terraform.tfplan
```

### Step 8: SSM Parameters (Application-Specific)

**IMPORTANT**: SSM Parameters are NOT created by Terraform infrastructure deployment. They are for application secrets only.

**What Terraform Creates**:
- Infrastructure resources (VPC, EC2, RDS, ALB, etc.)
- IAM roles for EC2 instances to read SSM parameters
- Security groups and networking

**What You Create Manually AFTER Infrastructure**:
Application secrets that the ML server Docker container needs:

```bash
# Example: If your ML server needs API keys
aws ssm put-parameter \
  --name "/humansa/production/ml/anthropic_key" \
  --value "YOUR_KEY" \
  --type "SecureString" \
  --region ap-east-1

# The ML server deployment scripts will read these from SSM
```

**Note**: The infrastructure deployment only needs the Terraform variables (DB_USERNAME, DB_PASSWORD, etc.) which are passed through GitHub Secrets. Application-specific secrets like API keys are handled separately by the application deployment process.

### Step 9: Configure Terraform Variables

**Why**: Environment-specific configuration.

Create `environments/production/terraform.tfvars`:
```hcl
project_name = "humansa"
environment  = "production"
region       = "ap-east-1"

# Networking
vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-east-1a", "ap-east-1b"]

# Database
db_instance_class = "db.t3.small"
db_allocated_storage = 100

# Compute
instance_type = "t3.medium"
min_size = 2
max_size = 4

# Domain (update after Route53 setup)
domain_name = "api.humansa.ai"
```

### Step 10: Deploy Infrastructure

**Why**: Create all AWS resources using the tag-based workflow.

```bash
# 1. Initialize repository and push code
cd /Users/shonnli/Non-icloudFile/YouWoAI/Code_V1/humansa-infrastructure
git init
git add .
git commit -m "Initial infrastructure setup"
git branch -M main
git remote add origin git@github.com:Shonn-Li/humansa-infrastructure.git
git push -u origin main

# 2. Create a plan (this triggers GitHub Actions)
git tag plan-v1.0.0
git push origin plan-v1.0.0

# 3. Check GitHub Actions tab for the plan
# Go to: https://github.com/Shonn-Li/humansa-infrastructure/actions
# Review the Terraform plan output

# 4. If plan looks good, apply it
git tag apply-v1.0.0
git push origin apply-v1.0.0

# 5. Monitor deployment in GitHub Actions
# Infrastructure creation takes ~15-20 minutes
```

**Deployment Flow**:
1. `plan-*` tag → Runs terraform plan → Saves to S3
2. Review plan output in GitHub Actions logs
3. `apply-*` tag → Downloads plan from S3 → Applies it
4. Infrastructure is created in AWS

### Step 11: Post-Deployment Configuration

**Why**: Final setup steps after infrastructure is created.

1. **Update DNS Records**:
   - Get ALB DNS name from Terraform output
   - Create CNAME record pointing domain to ALB

2. **Configure SSL Certificate**:
   - Request ACM certificate for domain
   - Update ALB listener with certificate

3. **Deploy Application**:
   - SSH to EC2 instances
   - Verify ML server is running
   - Test health endpoint

## Manual UI Interactive Steps

### AWS Console Steps

1. **Verify OIDC Provider**:
   - IAM → Identity providers
   - Check token.actions.githubusercontent.com exists

2. **Check IAM Role**:
   - IAM → Roles → humansa-github-actions-role
   - Verify trust relationship includes your GitHub repo

3. **Monitor First Deployment**:
   - EC2 → Instances: Check instances are healthy
   - RDS → Databases: Verify database is available
   - EC2 → Load Balancers: Check target health

### GitHub UI Steps

1. **Repository Settings**:
   - Settings → Secrets and variables → Actions
   - Verify all secrets are set correctly

2. **Actions Tab**:
   - Monitor workflow runs
   - Check for any errors in logs

## Troubleshooting

### Common Issues

1. **OIDC Authentication Fails**:
   - Check trust policy has correct GitHub repo path
   - Verify OIDC provider thumbprint is correct

2. **Terraform State Lock**:
   ```bash
   # Force unlock if needed
   terraform force-unlock LOCK_ID
   ```

3. **EC2 Instances Not Healthy**:
   - Check security group rules
   - Verify user data script execution
   - Check CloudWatch logs

### Validation Commands

```bash
# Check infrastructure status
aws ec2 describe-instances --filters "Name=tag:Project,Values=humansa"
aws rds describe-db-instances --db-instance-identifier humansa-production
aws elbv2 describe-load-balancers --names humansa-production-alb

# Test application endpoint
curl -k https://YOUR_ALB_DNS/health
```

## Security Considerations

1. **Never commit secrets** to Git
2. **Use SSM Parameter Store** for all application secrets
3. **Rotate credentials** regularly
4. **Enable CloudTrail** for audit logging
5. **Use HTTPS only** for API endpoints

## Next Steps After Setup

1. Configure monitoring alerts
2. Set up backup automation
3. Implement log aggregation
4. Create runbooks for common operations
5. Plan for disaster recovery