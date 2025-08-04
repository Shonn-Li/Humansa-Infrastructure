# Complete Credential & Secret Management Analysis

## 🔍 **YouWoAI vs Humansa Credential Flow**

Based on deep analysis of YouWoAI's infrastructure, here's exactly how credentials and secrets are managed and what you need to replicate for Humansa.

---

## 🔐 **1. AWS Authentication Methods**

### **YouWoAI Uses:**
**OIDC (OpenID Connect) Role-Based Authentication** - No access keys stored in GitHub!

```yaml
# From YouWoAI's plan.yml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v1
  with:
    role-to-assume: ${{ secrets.AWS_ROLE }}  # IAM Role ARN, not access keys!
    aws-region: ${{ secrets.AWS_REGION }}
    role-session-name: GitHub-OIDC-TERRAFORM
```

**What this means:**
- ✅ **No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY in GitHub secrets**
- ✅ **Uses IAM Role with OIDC trust relationship**
- ✅ **More secure than access keys**

---

## 📋 **2. Complete GitHub Secrets Analysis**

### **YouWoAI GitHub Secrets (Found in workflows):**

| Secret Name | Purpose | Goes To | Example Value |
|-------------|---------|---------|---------------|
| `AWS_ROLE` | IAM Role ARN for OIDC | GitHub Actions | `arn:aws:iam::123456789:role/youwoai-terraform-aws-tfstates` |
| `AWS_REGION` | AWS Region | GitHub Actions + Terraform | `us-west-1` |
| `DB_USERNAME` | Database master user | Terraform variable | `youwoai_admin` |
| `DB_PASSWORD` | Database master password | Terraform variable | `secure-password-123` |
| `ROUTE53_ZONE_ID` | DNS hosted zone | Terraform variable | `Z1234567890ABC` |
| `REDIS_PASSWORD` | Redis auth password | Terraform variable | `redis-secure-pass` |
| `GHCR_PAT` | GitHub Container Registry token | Terraform variable | `ghp_1234567890abcdef` |

### **No Bucket/DynamoDB Names in Secrets**
- ❌ No `AWS_BUCKET_NAME` or `DYNAMODB_TABLE_NAME` 
- ✅ These are **hardcoded in providers.tf**

---

## 🗄️ **3. SSM Parameter Store Usage**

### **What YouWoAI Stores in SSM (Terraform Creates These):**

| SSM Parameter | Source | Used By | Purpose |
|---------------|--------|---------|----------|
| `/youwoai/prod/db_host` | RDS endpoint | YouWoAI Server App | Database connection |
| `/youwoai/prod/db_port` | RDS port | YouWoAI Server App | Database connection |
| `/youwoai/prod/db_username` | Terraform var | YouWoAI Server App | Database auth |
| `/youwoai/prod/db_password` | Terraform var | YouWoAI Server App | Database auth |
| `/youwoai/prod/redis_host` | ElastiCache endpoint | YouWoAI Server App | Redis connection |
| `/youwoai/prod/redis_port` | ElastiCache port | YouWoAI Server App | Redis connection |
| `/youwoai/prod/redis_password` | Terraform var | YouWoAI Server App | Redis auth |
| `/youwoai/prod/ghcr_pat` | Terraform var | EC2 User Data | Container pull |
| `/youwoai/prod/server_image_tag` | Fixed "latest" | EC2 instances | Container version |
| `/youwoai/prod/tg_arn` | ALB Target Group ARN | Deployment scripts | Health checks |
| `/youwoai/prod/alb_arn` | Load Balancer ARN | Deployment scripts | Infrastructure ref |
| `/youwoai/prod/asg_name` | Auto Scaling Group name | Deployment scripts | Scaling operations |
| `/youwoai/prod/image_s3_bucket_name` | S3 bucket name | YouWoAI Server App | File uploads |
| `/youwoai/prod/audio_s3_bucket_name` | S3 bucket name | YouWoAI Server App | Audio uploads |
| `/youwoai/prod/file_s3_bucket_name` | S3 bucket name | YouWoAI Server App | File uploads |

---

## 🚀 **4. YouWoAI Deployment Flow**

### **Plan Process:**
1. **Push tag**: `git tag plan-v1.2.3 && git push origin plan-v1.2.3`
2. **GitHub Actions**:
   - Assumes IAM role via OIDC
   - Runs `terraform init` (connects to S3 backend)
   - Runs `terraform plan` with variables from secrets
   - Uploads plan file to S3: `s3://youwoai-terraform-state/plans/plan-v1.2.3.tfplan`

### **Apply Process:**
1. **Push tag**: `git tag apply-v1.2.3 && git push origin apply-v1.2.3`
2. **GitHub Actions**:
   - Assumes IAM role via OIDC
   - Downloads plan from S3: `plan-v1.2.3.tfplan`
   - Runs `terraform apply` with the downloaded plan
   - Updates SSM parameters with new infrastructure values

---

## 🎯 **5. What You Need for Humansa**

### **Option A: Manual Deployment (Recommended to Start)**

**No GitHub secrets needed. Just:**

1. **Create IAM user** with access keys for local Terraform
2. **Configure AWS CLI** with access keys
3. **Run terraform locally** with terraform.tfvars

### **Option B: Automated Deployment (Like YouWoAI)**

**Required AWS Setup:**
1. **Create OIDC Identity Provider** in IAM
2. **Create IAM Role** with trust relationship to GitHub
3. **Create GitHub Secrets** (see section 6)

---

## 📝 **6. Humansa GitHub Secrets (If You Want Automation)**

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `AWS_ROLE` | `arn:aws:iam::YOUR-ACCOUNT:role/humansa-terraform-role` | OIDC role assumption |
| `AWS_REGION` | `ap-east-1` | Hong Kong region |
| `DB_USERNAME` | `humansa_admin` | Database master user |
| `DB_PASSWORD` | `your-secure-password` | Database master password |
| `ROUTE53_ZONE_ID` | `Z1234567890ABC` | Your youwo.ai zone ID |
| `GHCR_PAT` | `ghp_your-token` | GitHub Container Registry |

**Note:** No Redis password needed (Humansa doesn't use Redis)

---

## 🏗️ **7. Humansa SSM Parameters (Terraform Will Create)**

```hcl
# These will be created automatically by Terraform:
/humansa/production/db_host
/humansa/production/db_port  
/humansa/production/db_username
/humansa/production/db_password
/humansa/production/github_pat
/humansa/production/api_tokens (multiple)
/humansa/production/alb_dns_name
/humansa/production/target_group_arn
/humansa/production/asg_name
/humansa/production/image_tag
```

---

## ⚙️ **8. Required Manual Setup Steps**

### **For Manual Deployment:**
1. ✅ Create S3 bucket: `humansa-terraform-state`
2. ✅ Create DynamoDB table: `humansa-terraform-state-locking`
3. ✅ Create IAM user: `humansa-terraform-user` with AdministratorAccess
4. ✅ Configure `terraform.tfvars` with your secrets
5. ✅ Run `terraform init && terraform apply`

### **For Automated Deployment (Additional):**
1. ✅ Create OIDC Identity Provider in IAM
2. ✅ Create IAM Role with GitHub trust relationship
3. ✅ Add GitHub repository secrets
4. ✅ Create GitHub Actions workflows

---

## 🔄 **9. Migration from YouWoAI Pattern**

**Differences for Humansa:**
- ❌ **No Redis** (removed for cost savings)
- ❌ **No CloudFront** (API servers don't need CDN)
- ❌ **No custom_header_key** (no CloudFront validation)
- ✅ **Hong Kong region** instead of us-west-1
- ✅ **Simplified architecture** (fewer services)
- ✅ **Same SSM parameter pattern** (but different prefix)

---

## 🚨 **Key Insights You Were Missing**

1. **YouWoAI uses OIDC roles, not access keys** for GitHub Actions
2. **Bucket/table names ARE hardcoded** in terraform files
3. **GitHub secrets only contain input variables** for terraform
4. **SSM parameters are OUTPUT** from terraform (infrastructure info)
5. **Applications read from SSM** (not from terraform.tfvars)
6. **Plan files stored in S3** for review before apply

**This explains why you didn't see AWS access keys in GitHub secrets - YouWoAI uses the more secure OIDC method!**