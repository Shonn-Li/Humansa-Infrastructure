# GitHub OIDC Setup for Humansa Infrastructure

## 🔍 **Understanding OIDC vs Access Keys**

### **What You Found: `youwoai-terraform-aws-tfstates`**

This is indeed the **OIDC Role** that YouWoAI uses for GitHub Actions! Let me explain exactly what this is and how to create one for Humansa.

---

## 🤔 **How to Verify YouWoAI Uses OIDC**

Run this command to check YouWoAI's role:

```bash
aws iam get-role --role-name youwoai-terraform-aws-tfstates --query 'Role.AssumeRolePolicyDocument'
```

**If it shows something like this, it's OIDC:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:sub": "repo:youwoai/YouWoAI-Infrastructure:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**Key indicators of OIDC:**
- ✅ `"Federated": "...oidc-provider/token.actions.githubusercontent.com"`
- ✅ `"token.actions.githubusercontent.com:sub": "repo:youwoai/..."`
- ❌ No `"AWS": "arn:aws:iam::...user/..."` (that would be access keys)

---

## 🔐 **OIDC vs Access Keys Comparison**

| Method | Security | Setup Complexity | GitHub Secrets |
|--------|----------|------------------|----------------|
| **Access Keys** | ⚠️ Keys stored in GitHub | Simple | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| **OIDC Role** | ✅ No keys stored | Complex | `AWS_ROLE` (just the ARN) |

**OIDC is more secure** because:
- No long-term credentials stored in GitHub
- GitHub proves its identity to AWS
- AWS temporarily grants access
- Automatic credential rotation

---

## 🚀 **Setting Up OIDC for Humansa (Optional)**

### **Prerequisites**
- GitHub repository: `youwoai/humansa-infrastructure`
- AWS Account with admin access
- Decision to use automated deployment

### **Step 1: Check if GitHub OIDC Provider Exists**

```bash
# Check if OIDC provider already exists (YouWoAI might have created it)
aws iam list-open-id-connect-providers
```

**Look for:**
```json
{
  "OpenIDConnectProviderList": [
    {
      "Arn": "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
    }
  ]
}
```

### **Step 2A: Create OIDC Provider (If Not Exists)**

```bash
# Only run this if Step 1 showed no GitHub OIDC provider
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
```

### **Step 2B: Use Existing Provider (If Exists)**

```bash
# Note the ARN from Step 1 for use in Step 3
OIDC_PROVIDER_ARN="arn:aws:iam::YOUR-ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
```

### **Step 3: Create Trust Policy**

```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create trust policy file
cat > humansa-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:sub": [
            "repo:youwoai/humansa-infrastructure:ref:refs/heads/main",
            "repo:youwoai/humansa-infrastructure:ref:refs/heads/optimize-infrastructure"
          ],
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

echo "Trust policy created for GitHub repo: youwoai/humansa-infrastructure"
```

### **Step 4: Create IAM Role**

```bash
# Create the role
aws iam create-role \
    --role-name humansa-terraform-aws-tfstates \
    --assume-role-policy-document file://humansa-trust-policy.json \
    --description "OIDC role for Humansa Terraform deployments via GitHub Actions"

# Attach admin policy (same as YouWoAI)
aws iam attach-role-policy \
    --role-name humansa-terraform-aws-tfstates \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo "✅ Role created: humansa-terraform-aws-tfstates"
```

### **Step 5: Get Role ARN**

```bash
# Get the role ARN for GitHub secrets
aws iam get-role --role-name humansa-terraform-aws-tfstates --query 'Role.Arn' --output text
```

**Save this ARN - you'll need it for GitHub secrets!**

### **Step 6: Clean Up**

```bash
# Remove temporary files
rm humansa-trust-policy.json
```

---

## 📝 **GitHub Repository Setup**

### **Required GitHub Secrets (For OIDC)**

Go to your GitHub repo → Settings → Secrets and variables → Actions:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `AWS_ROLE` | `arn:aws:iam::123456789:role/humansa-terraform-aws-tfstates` | From Step 5 |
| `AWS_REGION` | `ap-east-1` | Hong Kong region |
| `DB_USERNAME` | `humansa_admin` | Database user |
| `DB_PASSWORD` | `your-secure-password` | Database password |
| `ROUTE53_ZONE_ID` | `Z1234567890ABC` | Your youwo.ai zone |
| `GHCR_PAT` | `ghp_your-token` | GitHub container registry |

### **GitHub Actions Workflow Example**

```yaml
# .github/workflows/terraform-plan.yml
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
  TF_VAR_db_username: ${{ secrets.DB_USERNAME }}
  TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
  TF_VAR_route53_zone_id: ${{ secrets.ROUTE53_ZONE_ID }}
  TF_VAR_github_pat: ${{ secrets.GHCR_PAT }}

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

---

## 🎯 **Decision: Manual vs Automated**

### **For Manual Deployment (Recommended Start):**
- ✅ **Skip OIDC setup entirely**
- ✅ **Use IAM user with access keys**
- ✅ **Run terraform locally**
- ✅ **Faster to get started**

### **For Automated Deployment:**
- ✅ **Set up OIDC (this guide)**
- ✅ **Create GitHub Actions workflows**
- ✅ **More secure long-term**
- ✅ **Team collaboration**

---

## 🔍 **Troubleshooting OIDC Setup**

### **Common Issues:**

1. **"No OpenIDConnect provider found"**
   - Run Step 2A to create the provider

2. **"Invalid trust policy"**
   - Check the repo name in trust policy
   - Ensure branch names are correct

3. **"Access denied"**
   - Verify the role has AdministratorAccess policy
   - Check the trust relationship conditions

### **Test OIDC Setup:**

```bash
# Test assuming the role (if you have local admin access)
aws sts assume-role \
    --role-arn arn:aws:iam::123456789:role/humansa-terraform-aws-tfstates \
    --role-session-name test-session
```

---

## 📋 **Summary**

**YouWoAI's `youwoai-terraform-aws-tfstates` role is indeed an OIDC role** that allows GitHub Actions to securely access AWS without storing credentials.

**For Humansa, you have two options:**
1. **Manual deployment** (simpler, recommended first)
2. **OIDC + GitHub Actions** (more secure, follow this guide)

**The role ARN format is:**
`arn:aws:iam::YOUR-ACCOUNT-ID:role/humansa-terraform-aws-tfstates`

This provides the same secure, keyless authentication that YouWoAI uses for their infrastructure deployments.