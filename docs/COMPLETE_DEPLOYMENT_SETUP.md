# Complete Humansa AWS Deployment Setup Guide

This comprehensive guide covers all manual setup steps, credentials, and configurations needed to deploy Humansa infrastructure to AWS.

## 📋 **Prerequisites Checklist**

- [ ] AWS Account with billing enabled
- [ ] AWS CLI installed locally
- [ ] Terraform >= 1.0 installed locally
- [ ] GitHub account with repository access
- [ ] Domain control for youwo.ai
- [ ] Email access for alerts

---

## 🔐 **Step 1: AWS Account & IAM Setup**

### **1.1 Create IAM User for Terraform**

**Why needed**: Terraform needs AWS credentials to create/manage resources. Never use root account.

```bash
# Option A: Via AWS CLI (if you have admin access)
aws iam create-user --user-name humansa-terraform-user

# Attach administrator policy (needed for full infrastructure deployment)
aws iam attach-user-policy \
    --user-name humansa-terraform-user \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access keys
aws iam create-access-key --user-name humansa-terraform-user
```

**Option B: Via AWS Console** (Recommended for first-time setup):
1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. Username: `humansa-terraform-user`
4. Attach policies directly: `AdministratorAccess`
5. Create user
6. Go to user → Security credentials → Create access key
7. Use case: "CLI" → Create
8. **SAVE THE ACCESS KEY AND SECRET** - you can't see the secret again!

### **1.2 Configure AWS CLI**

```bash
aws configure
# AWS Access Key ID: [Paste your access key]
# AWS Secret Access Key: [Paste your secret key]
# Default region name: ap-east-1
# Default output format: json

# Test the connection
aws sts get-caller-identity
```

**Expected output**:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/humansa-terraform-user"
}
```

---

## 🏗️ **Step 2: Terraform Backend Setup (CRITICAL)**

**Why needed**: Terraform stores infrastructure state. Without proper backend, you can't manage infrastructure safely.

### **2.1 Create S3 Bucket for State Storage**

#### **Option A: Via AWS CLI**
```bash
# Generate unique bucket name (S3 bucket names must be globally unique)
BUCKET_NAME="humansa-terraform-state-$(date +%s)"
echo "Your bucket name: $BUCKET_NAME"

# Create the bucket
aws s3 mb s3://$BUCKET_NAME --region ap-east-1

# Enable versioning (CRITICAL for state recovery)
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Block all public access (security)
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable server-side encryption
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

#### **Option B: Via AWS Console** (Recommended)
1. Go to **AWS Console → S3**
2. Click **"Create bucket"**
3. **Bucket name**: `humansa-terraform-state-[add-random-numbers]`
   - Example: `humansa-terraform-state-1672891234`
   - Must be globally unique!
4. **Region**: `Asia Pacific (Hong Kong) ap-east-1`
5. **Block Public Access**: ✅ Check "Block all public access"
6. **Bucket Versioning**: ✅ Enable
7. **Default encryption**: ✅ Enable (Server-side encryption with Amazon S3 managed keys)
8. Click **"Create bucket"**

**📝 Write down your exact bucket name**: `_______________________`

### **2.2 Create DynamoDB Table for State Locking**

**Why needed**: Prevents multiple `terraform apply` operations from running simultaneously.

#### **Option A: Via AWS CLI**
```bash
# Create DynamoDB table for locking
aws dynamodb create-table \
    --table-name humansa-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region ap-east-1

# Verify table creation
aws dynamodb describe-table --table-name humansa-terraform-locks --region ap-east-1
```

#### **Option B: Via AWS Console** (Recommended)
1. Go to **AWS Console → DynamoDB**
2. Click **"Create table"**
3. **Table name**: `humansa-terraform-locks` (exact name!)
4. **Partition key**: `LockID` (Type: String)
5. **Table settings**: Use default settings
6. **Read/write capacity settings**: Provisioned
   - **Read capacity**: 5 units
   - **Write capacity**: 5 units
7. Click **"Create table"**
8. Wait for status to show **"Active"**

**Expected table details**:
- Table name: `humansa-terraform-locks`
- Partition key: `LockID` (String)
- Status: Active
- Region: ap-east-1

---

## 🌐 **Step 3: Domain & DNS Setup**

### **3.1 Get Route53 Hosted Zone ID**

**Why needed**: Terraform needs this to create DNS records for your domain.

```bash
# Find your youwo.ai hosted zone ID
aws route53 list-hosted-zones-by-name --dns-name youwo.ai
```

**Look for output like**:
```json
{
    "HostedZones": [
        {
            "Id": "/hostedzone/Z1234567890ABC",
            "Name": "youwo.ai."
        }
    ]
}
```

**📝 Your Zone ID** (remove the `/hostedzone/` part): `_______________________`

### **3.2 If you DON'T have youwo.ai in Route53**:

1. Go to AWS Console → Route 53 → Hosted zones
2. Click "Create hosted zone"
3. Domain name: `youwo.ai`
4. Type: Public hosted zone
5. Click "Create hosted zone"
6. **IMPORTANT**: Update your domain registrar's nameservers to the 4 NS records shown
7. Wait 24-48 hours for DNS propagation

---

## 🔑 **Step 4: Generate Required Secrets & Keys**

### **4.1 SSH Key Pair**

**Why needed**: For secure access to EC2 instances.

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/humansa-key -C "humansa-infrastructure"

# View public key (you'll need this for terraform.tfvars)
cat ~/.ssh/humansa-key.pub
```

**📝 Copy your public key**: `_______________________`

### **4.2 Database Password**

**Why needed**: RDS PostgreSQL master password.

```bash
# Generate secure 32-character password
openssl rand -base64 32
```

**📝 Your database password**: `_______________________`

### **4.3 API Tokens**

**Why needed**: For authenticating requests to your ML API.

```bash
# Generate 3 API tokens (run this command 3 times)
echo "hstoken_$(openssl rand -hex 16)"
```

**📝 Your API tokens**:
1. `_______________________`
2. `_______________________`
3. `_______________________`

---

## 📱 **Step 5: GitHub Integration Setup**

### **5.1 Create GitHub Personal Access Token**

**Why needed**: EC2 instances need to pull container images from GitHub Container Registry.

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Note: "Humansa Infrastructure Deployment"
4. Expiration: "No expiration" (or set to 1 year)
5. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `packages:write` (Upload packages to GitHub Package Registry)
   - ✅ `packages:read` (Download packages from GitHub Package Registry)
6. Click "Generate token"
7. **COPY THE TOKEN IMMEDIATELY** - you won't see it again

**📝 Your GitHub PAT** (starts with `ghp_`): `_______________________`

### **5.3 GitHub Repository Secrets (Optional - for CI/CD)**

If you want to set up automated deployment via GitHub Actions (like YouWoAI), you'll need these repository secrets:

**Go to your GitHub repo → Settings → Secrets and variables → Actions**

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `AWS_ACCESS_KEY_ID` | Your Terraform user access key | Terraform deployment |
| `AWS_SECRET_ACCESS_KEY` | Your Terraform user secret key | Terraform deployment |
| `AWS_REGION` | `ap-east-1` | Hong Kong region |
| `TF_VAR_db_password` | Your database password | Terraform variables |
| `TF_VAR_github_pat` | Your GitHub PAT | Terraform variables |
| `TF_VAR_route53_zone_id` | Your Route53 zone ID | Terraform variables |

**Note**: The `TF_VAR_` prefix automatically passes these as Terraform variables.

### **5.2 Verify GitHub Container Registry Access**

```bash
# Test GitHub Container Registry access
echo "YOUR_GITHUB_PAT" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Expected output: "Login Succeeded"
```

### **5.3 Container Repository Setup**

Your ML server container should be available at:
```
ghcr.io/youwoai/humansa-ml-server:latest
```

**Ensure your container**:
- [ ] Exposes port 5000
- [ ] Has a `/health` endpoint
- [ ] Reads configuration from environment variables or AWS SSM

---

## 📝 **Step 6: Configure Terraform Variables**

### **6.1 Navigate to Production Environment**

```bash
cd humansa-infrastructure/environments/production
```

### **6.2 Update Terraform Backend Configuration**

Edit `main.tf` and update the backend section with your actual bucket name:

```hcl
backend "s3" {
  bucket         = "humansa-terraform-state-1234567890"  # YOUR ACTUAL BUCKET NAME
  key            = "production/terraform.tfstate"
  region         = "ap-east-1"
  encrypt        = true
  dynamodb_table = "humansa-terraform-locks"
}
```

### **6.3 Create terraform.tfvars File**

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Fill in ALL values with your actual data**:

```hcl
# AWS Configuration
aws_region = "ap-east-1"

# Database Configuration
db_username = "humansa_admin"
db_password = "YOUR_DATABASE_PASSWORD_FROM_STEP_4"
db_name     = "humansa"

# Domain & Route53 Configuration
domain_name     = "humansa.youwo.ai"
route53_zone_id = "YOUR_ROUTE53_ZONE_ID_FROM_STEP_3"

# API Tokens for Authentication
api_tokens = [
  "YOUR_API_TOKEN_1_FROM_STEP_4",
  "YOUR_API_TOKEN_2_FROM_STEP_4", 
  "YOUR_API_TOKEN_3_FROM_STEP_4"
]

# Instance Configuration
instance_type     = "t3.medium"
min_instances     = 2
desired_instances = 2
max_instances     = 4

# Monitoring Configuration
alarm_email = "your-email@youwo.ai"  # YOUR ACTUAL EMAIL

# GitHub Configuration  
github_pat  = "YOUR_GITHUB_PAT_FROM_STEP_5"
github_repo = "youwoai/humansa-ml-server"

# SSH Key Configuration
ssh_public_key = "YOUR_SSH_PUBLIC_KEY_FROM_STEP_4"

# Production Settings (for safety)
enable_deletion_protection = true
db_deletion_protection     = true
db_skip_final_snapshot     = false
```

**🔒 SECURITY WARNING**: Never commit `terraform.tfvars` to git! It contains secrets.

---

## 🚀 **Step 7: Deploy Infrastructure**

### **7.1 Initialize Terraform**

```bash
# Initialize Terraform (downloads providers, sets up backend)
terraform init

# Expected output: "Terraform has been successfully initialized!"
```

### **7.2 Validate Configuration**

```bash
# Check for syntax errors
terraform validate

# Expected output: "Success! The configuration is valid."
```

### **7.3 Plan Deployment**

```bash
# Create execution plan
terraform plan -var-file="terraform.tfvars"

# Review the output carefully - should show ~50+ resources to create
# Look for any errors or warnings
```

### **7.4 Apply Infrastructure**

```bash
# Deploy infrastructure (takes 15-20 minutes)
terraform apply -var-file="terraform.tfvars"

# Type 'yes' when prompted
# Wait for completion...
```

**Expected final output**:
```
Apply complete! Resources: 52 added, 0 changed, 0 destroyed.

Outputs:
load_balancer_url = "https://humansa.youwo.ai"
vpc_id = "vpc-1234567890abcdef0"
...
```

---

## ✅ **Step 8: Post-Deployment Verification**

### **8.1 Check Infrastructure Status**

```bash
# View all outputs
terraform output

# Test DNS resolution
nslookup humansa.youwo.ai

# Test SSL certificate
curl -I https://humansa.youwo.ai
```

### **8.2 Verify SSL Certificate**

**Expected response**:
```
HTTP/2 200 
server: awselb/2.0
date: Mon, 01 Jan 2024 12:00:00 GMT
```

### **8.3 Test API Endpoint**

```bash
# Test with one of your API tokens
curl -H "Authorization: Bearer YOUR_API_TOKEN_1" \
     https://humansa.youwo.ai/health

# Expected: {"status": "healthy"} or similar
```

---

## 🔧 **Step 9: Application Deployment & EC2 Setup**

### **9.1 Connect to EC2 Instance**

```bash
# Find your instance ID
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=humansa-production-ml-server" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
    --output table

# Connect via EC2 Instance Connect (recommended)
aws ec2-instance-connect ssh --instance-id i-1234567890abcdef0
```

### **9.2 Manual Application Setup** (if user-data fails)

```bash
# Once connected to EC2 instance:

# Check if Docker is running
sudo systemctl status docker

# Check user-data logs
sudo cat /var/log/cloud-init-output.log

# If container isn't running, start manually:
sudo docker pull ghcr.io/youwoai/humansa-ml-server:latest

# Run container with environment variables
sudo docker run -d \
    --name humansa-ml \
    --restart unless-stopped \
    -p 5000:5000 \
    -e AWS_REGION=ap-east-1 \
    -e PROJECT_NAME=humansa \
    -e ENVIRONMENT=production \
    -e INSTANCE_ID=$(cat /var/lib/cloud/data/instance-id) \
    ghcr.io/youwoai/humansa-ml-server:latest

# Check container status
sudo docker ps
sudo docker logs humansa-ml
```

### **9.3 Verify Application Health**

```bash
# Test from inside EC2
curl http://localhost:5000/health

# Test from outside
curl https://humansa.youwo.ai/health
```

---

## 📊 **Step 10: Set Up Monitoring & Alerts**

### **10.1 CloudWatch Dashboard**

1. Go to AWS Console → CloudWatch → Dashboards
2. Create dashboard: "Humansa Production"  
3. Add widgets for:
   - EC2 CPU Utilization
   - ALB Request Count
   - ALB Response Time
   - Database CPU/Connections
   - Auto Scaling Group metrics

### **10.2 Billing Alerts**

1. Go to AWS Console → Billing → Budgets
2. Create budget: "Humansa Monthly"
3. Set amount: $200 (base cost ~$175)
4. Set alerts: 80%, 100%, 110%
5. Email: your-email@youwo.ai

### **10.3 SNS Topic Verification**

Check your email for SNS subscription confirmation and click "Confirm subscription".

---

## 📋 **Important Reminders & Considerations**

### **🔒 Security Checklist**
- [ ] `terraform.tfvars` is in `.gitignore` (never commit secrets)
- [ ] IAM user has minimal required permissions
- [ ] SSH access restricted to your IP only
- [ ] Database in private subnets
- [ ] All storage encrypted
- [ ] SSL/TLS everywhere

### **💰 Cost Management**
- **Expected monthly cost**: $175 (base) - $242 (peak)
- **Set billing alerts**: $150, $200, $250
- **Monitor daily**: Check AWS Cost Explorer weekly
- **Reserved Instances**: Consider for 30% savings after stable operation

### **🔄 Operational Tasks**

**Daily**:
- [ ] Check CloudWatch alarms
- [ ] Monitor application logs
- [ ] Verify SSL certificate expiry (auto-renewed)

**Weekly**:
- [ ] Review cost reports
- [ ] Check security group rules
- [ ] Verify backup retention

**Monthly**:
- [ ] Rotate API tokens
- [ ] Review IAM permissions
- [ ] Update container images
- [ ] Test disaster recovery

### **📝 Keep These Safe**
- AWS Access Key & Secret
- Database password
- SSH private key (`~/.ssh/humansa-key`)
- API tokens
- GitHub PAT
- Route53 Zone ID
- S3 bucket name for Terraform state

### **🚨 Emergency Procedures**

**If infrastructure breaks**:
```bash
# Check Terraform state
terraform show

# Emergency scale up
terraform apply -var desired_instances=4

# Emergency rollback (if you have previous state)
terraform apply -target=module.compute
```

**If database issues**:
```bash
# Create emergency snapshot
aws rds create-db-snapshot \
    --db-instance-identifier humansa-production-db \
    --db-snapshot-identifier emergency-$(date +%Y%m%d-%H%M%S)
```

---

## 🎯 **Success Criteria**

Your deployment is successful when:

✅ **Infrastructure**:
- [ ] Terraform apply completes without errors
- [ ] All AWS resources created (VPC, EC2, RDS, ALB, etc.)
- [ ] DNS resolves: `nslookup humansa.youwo.ai`
- [ ] SSL works: `curl -I https://humansa.youwo.ai`

✅ **Application**:
- [ ] Container running on EC2 instances
- [ ] Health check passes: `curl https://humansa.youwo.ai/health`
- [ ] API authentication works with your tokens
- [ ] Load balancer distributing traffic

✅ **Monitoring**:
- [ ] CloudWatch alarms configured
- [ ] SNS notifications working (check email)
- [ ] Application logs appearing in CloudWatch

✅ **Security**:
- [ ] HTTPS-only access
- [ ] Database in private subnets
- [ ] Security groups properly configured
- [ ] Secrets stored in SSM Parameter Store

---

## 📞 **Troubleshooting Common Issues**

### **Issue**: Terraform backend initialization fails
**Solution**: 
- Verify S3 bucket exists and you have access
- Check DynamoDB table is ACTIVE status
- Ensure AWS credentials are correct

### **Issue**: Route53 certificate validation fails  
**Solution**:
- Check DNS propagation: `dig humansa.youwo.ai`
- Verify Route53 zone ID is correct
- Wait up to 10 minutes for validation

### **Issue**: EC2 instances fail to start application
**Solution**:
- SSH to instance: Check `/var/log/cloud-init-output.log`
- Verify GitHub PAT has correct permissions
- Check container can be pulled: `docker pull ghcr.io/youwoai/humansa-ml-server:latest`

### **Issue**: Load balancer health checks fail
**Solution**:
- Verify application exposes port 5000
- Check `/health` endpoint returns 200 status
- Review security group rules for port 5000

---

**🎉 Congratulations!** If you've completed all steps, your Humansa infrastructure is now live at `https://humansa.youwo.ai`!