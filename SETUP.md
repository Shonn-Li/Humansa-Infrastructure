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

### Step 4: Create GitHub Repository

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

### Step 5: Configure GitHub Secrets

**Why**: Securely store configuration for GitHub Actions.

Go to GitHub repository settings > Secrets and variables > Actions, then add:

1. **AWS_ROLE**: `arn:aws:iam::992382528744:role/humansa-github-actions-role`
2. **AWS_REGION**: `ap-east-1`
3. **DB_USERNAME**: `humansa_admin`
4. **DB_PASSWORD**: `[your-secure-database-password]`
5. **ROUTE53_ZONE_ID**: `[your-route53-zone-id-for-youwo.ai]`
6. **GHCR_PAT**: `[your-github-personal-access-token]`

**Note**: These secrets match YouWoAI's pattern. The Terraform backend configuration (S3 bucket, DynamoDB table) is handled in the Terraform files, not GitHub secrets.

### Step 6: Create GitHub Actions Workflows

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

### Step 7: Create SSM Parameters for Application Secrets

**Why**: Secure storage of application credentials that EC2 instances can access.

```bash
# Database password
aws ssm put-parameter \
  --name "/humansa/production/database/password" \
  --value "YOUR_SECURE_PASSWORD" \
  --type "SecureString" \
  --region ap-east-1

# API tokens
aws ssm put-parameter \
  --name "/humansa/production/api/openai_key" \
  --value "YOUR_OPENAI_KEY" \
  --type "SecureString" \
  --region ap-east-1

# Add other application secrets as needed
```

### Step 8: Configure Terraform Variables

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

### Step 9: Deploy Infrastructure

**Why**: Create all AWS resources.

```bash
# Create PR to trigger plan
git checkout -b initial-deployment
git add .
git commit -m "Initial infrastructure configuration"
git push origin initial-deployment

# Create PR on GitHub - this triggers terraform plan
# Review the plan output in PR comments

# After approval, merge PR and create deploy tag
git checkout main
git pull origin main
git tag deploy-v1.0.0
git push origin deploy-v1.0.0

# This triggers terraform apply automatically
```

### Step 10: Post-Deployment Configuration

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