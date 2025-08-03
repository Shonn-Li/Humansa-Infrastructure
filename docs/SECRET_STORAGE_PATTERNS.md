# Secret Storage Pattern Documentation

## Summary: Where Each Secret Type Goes

### 1. **terraform.tfvars** (Git-ignored, local file)
✅ **CORRECT PATTERN FOLLOWED**

**What goes here:**
- Database master credentials (for RDS creation)
- Route53 zone ID (not really secret)
- SSH public keys (not secret)
- GitHub PAT (for deployment automation)
- Initial API tokens
- Alarm email addresses

**Example:**
```hcl
db_username = "humansa_admin"
db_password = "StrongPassword123!"
api_tokens = ["token1", "token2", "token3"]
github_pat = "ghp_xxxxxxxxxxxxx"
```

**Security Note**: This file is `.gitignore`'d and never committed

### 2. **AWS SSM Parameter Store**
✅ **CORRECT PATTERN FOLLOWED**

**What goes here:**
- ALL runtime application secrets
- Database connection strings (AFTER creation)
- API keys (OpenAI, Anthropic, etc.)
- JWT/Session secrets
- Redis auth tokens
- Any config the app needs to read

**Pattern:**
```
/humansa/production/db/connection_string     # Created by Terraform
/humansa/production/api/openai_key          # Created by setup script
/humansa/production/auth/jwt_secret         # Created by setup script
```

**Why**: Applications fetch these at runtime, can be rotated without redeploy

### 3. **GitHub Repository Secrets**
✅ **CORRECT PATTERN FOLLOWED**

**What goes here:**
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY  
- SLACK_WEBHOOK (optional)
- Any CI/CD-only secrets

**Set via**: GitHub UI → Settings → Secrets → Actions

**Why**: Only needed during GitHub Actions workflows, never in application

### 4. **Environment Variables** 
✅ **CORRECT PATTERN FOLLOWED**

**What goes here:**
- NON-SECRET configuration only
- AWS_REGION
- ENVIRONMENT (production/staging)
- PROJECT_NAME
- PORT numbers

**Never put**: API keys, passwords, tokens

## Comparison with YouWoAI Pattern

| Secret Type | YouWoAI | Humansa | Location |
|------------|---------|---------|-----------|
| DB Password | ✓ | ✓ | terraform.tfvars → SSM |
| API Keys | ✓ | ✓ | SSM Parameter Store |
| GitHub PAT | ✓ | ✓ | terraform.tfvars → SSM |
| AWS Creds | ✓ | ✓ | GitHub Secrets |
| App Config | ✓ | ✓ | SSM Parameter Store |
| S3 Buckets | ✓ | ✗ | SSM (not needed) |

## Security Flow

1. **Infrastructure Creation**:
   ```
   terraform.tfvars → Terraform → Creates Resources → Stores in SSM
   ```

2. **Application Runtime**:
   ```
   EC2 Instance → IAM Role → Read from SSM → Application
   ```

3. **CI/CD Pipeline**:
   ```
   GitHub Secrets → GitHub Actions → AWS API calls
   ```

## Best Practices Followed

✅ **Separation of Concerns**
- Infrastructure secrets separate from runtime secrets
- CI/CD secrets isolated in GitHub

✅ **Least Privilege**
- EC2 can only read `/humansa/production/*`
- No hardcoded secrets in code

✅ **Rotation Capability**
- SSM parameters can be updated without redeploy
- API tokens stored as array for rolling updates

✅ **Audit Trail**
- SSM access logged in CloudTrail
- GitHub Actions logs show deployment history

## Key Differences from Bad Practices

❌ **NOT DOING**:
- Hardcoding secrets in code
- Storing secrets in plain environment variables
- Committing secrets to git
- Using the same credentials everywhere

✅ **DOING CORRECTLY**:
- Using AWS-native secret management (SSM)
- Separating build-time vs runtime secrets
- Following principle of least privilege
- Enabling secret rotation

## Validation Checklist

- [x] Database passwords: terraform.tfvars → SSM ✓
- [x] API Keys: SSM Parameter Store only ✓
- [x] AWS Credentials: GitHub Secrets only ✓
- [x] Runtime config: SSM Parameter Store ✓
- [x] No secrets in environment variables ✓
- [x] No secrets committed to git ✓