# Humansa Infrastructure Deployment Guide

This guide provides detailed instructions for deploying the Humansa ML API infrastructure using the modular Terraform configuration.

## 📋 Prerequisites Checklist

### AWS Requirements
- [ ] AWS Account with Administrator access
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Appropriate IAM permissions for all AWS services

### Domain & DNS
- [ ] Control of youwo.ai domain
- [ ] Route53 hosted zone for youwo.ai
- [ ] Access to Route53 zone ID

### GitHub & Container Registry
- [ ] GitHub repository for Humansa ML server
- [ ] GitHub Personal Access Token with package permissions
- [ ] Docker image pushed to GitHub Container Registry (ghcr.io)

### Local Environment
- [ ] SSH key pair generated
- [ ] Secure API tokens generated
- [ ] Database credentials chosen
- [ ] Alert email configured

## 🏗️ Deployment Steps

### Step 1: Repository Setup

```bash
# Clone the infrastructure repository
git clone https://github.com/Shonn-Li/Humansa-Infrastructure.git
cd Humansa-Infrastructure

# Choose your environment
cd environments/production  # or environments/staging
```

### Step 2: Terraform Backend Setup

Before first deployment, set up the Terraform state backend:

```bash
# Create S3 bucket for state storage
aws s3 mb s3://humansa-terraform-state --region ap-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket humansa-terraform-state \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name humansa-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region ap-east-1
```

### Step 3: Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your actual values
nano terraform.tfvars
```

#### Required Configuration Values

```hcl
# Database Configuration
db_username = "humansa_admin"
db_password = "SuperSecurePassword123!"  # Use a strong password
db_name = "humansa"

# Domain & Route53
domain_name = "humansa.youwo.ai"  # or "humansa-staging.youwo.ai" for staging
route53_zone_id = "Z1234567890ABC"  # Your actual hosted zone ID

# API Authentication Tokens
api_tokens = [
  "hstoken_prod_1a2b3c4d5e6f7g8h9i0j",
  "hstoken_prod_2k3l4m5n6o7p8q9r0s1t",
  "hstoken_prod_3u4v5w6x7y8z9a0b1c2d"
]

# GitHub Configuration
github_pat = "ghp_1234567890abcdef"  # Your GitHub PAT
github_repo = "youwoai/humansa-ml-server"

# SSH Access
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAC... your-email@domain.com"

# Monitoring
alarm_email = "alerts@youwo.ai"
```

#### Security Best Practices for Variables

1. **Database Password**: Use a strong, unique password (20+ characters)
2. **API Tokens**: Generate cryptographically secure tokens (32+ characters)
3. **GitHub PAT**: Minimal required permissions (packages:read)
4. **SSH Key**: Use ed25519 or RSA 4096-bit keys

### Step 4: Initialize Terraform

```bash
# Initialize Terraform (first time only)
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### Step 5: Plan Deployment

```bash
# Create execution plan
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Review the plan carefully
# Verify all resources look correct
# Check estimated costs
```

### Step 6: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply tfplan

# Monitor deployment progress
# This typically takes 15-20 minutes
```

### Step 7: Post-Deployment Verification

```bash
# Check deployment outputs
terraform output

# Verify DNS resolution
nslookup humansa.youwo.ai

# Test health endpoint
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://humansa.youwo.ai/health

# Check SSL certificate
curl -I https://humansa.youwo.ai
```

## 🔄 Environment-Specific Deployments

### Production Environment

```bash
cd environments/production

# Production-specific considerations:
# - Deletion protection enabled
# - Multi-AZ database option available
# - Full monitoring and alerting
# - Longer backup retention

terraform apply -var-file="terraform.tfvars"
```

### Staging Environment

```bash
cd environments/staging

# Staging-specific optimizations:
# - Smaller instances (t3.small vs t3.medium)
# - Single instance minimum
# - Shorter backup retention
# - Cost-optimized settings

terraform apply -var-file="terraform.tfvars"
```

## 🛠️ Common Deployment Issues

### Issue 1: Route53 Zone Not Found

**Error**: `Error: no matching Route53Zone found`

**Solution**:
```bash
# Find your hosted zone ID
aws route53 list-hosted-zones-by-name --dns-name youwo.ai
# Update route53_zone_id in terraform.tfvars
```

### Issue 2: Certificate Validation Timeout

**Error**: `Error waiting for certificate validation`

**Solution**:
```bash
# Check DNS propagation
dig _acme-challenge.humansa.youwo.ai

# Manually add validation records if needed
# Wait 5-10 minutes for DNS propagation
```

### Issue 3: GitHub Registry Authentication

**Error**: `Error: authentication required`

**Solution**:
```bash
# Verify GitHub PAT has correct permissions
# Scope: packages:read, packages:write

# Test access
echo $GITHUB_PAT | docker login ghcr.io -u USERNAME --password-stdin
```

### Issue 4: Instance Launch Failures

**Error**: `Error: instances failed to launch`

**Solution**:
```bash
# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "humansa"

# Verify user data script
# Check SSM parameter permissions
# Ensure GitHub PAT is accessible
```

## 📊 Monitoring Deployment

### CloudWatch Dashboards

After deployment, create custom dashboards:

```bash
# View Auto Scaling Group metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/AutoScaling \
    --metric-name GroupDesiredCapacity \
    --dimensions Name=AutoScalingGroupName,Value=humansa-production-ml-asg \
    --statistics Average \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-01T23:59:59Z \
    --period 3600
```

### Log Monitoring

```bash
# View application logs
aws logs tail /aws/application/humansa-production --follow

# View ALB access logs
aws s3 ls s3://humansa-production-alb-logs-12345678/alb-logs/
```

## 🔄 Updates and Maintenance

### Applying Configuration Changes

```bash
# Pull latest changes
git pull origin main

# Plan updates
terraform plan -var-file="terraform.tfvars"

# Apply updates
terraform apply -var-file="terraform.tfvars"
```

### Rolling Updates for Application Code

The infrastructure supports zero-downtime deployments through Auto Scaling Groups:

1. **GitHub Actions** pushes new container image
2. **User data script** pulls latest image on new instances
3. **Auto Scaling Group** performs rolling replacement
4. **Health checks** ensure availability throughout

### Scaling Operations

```bash
# Increase capacity temporarily
terraform apply -var desired_instances=4

# Scale back down
terraform apply -var desired_instances=2
```

## 💰 Cost Monitoring

### Daily Cost Tracking

```bash
# View daily costs
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-01-02 \
    --granularity DAILY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE
```

### Cost Optimization Tips

1. **Right-size instances** based on actual usage
2. **Use Reserved Instances** for stable workloads (30% savings)
3. **Monitor data transfer** costs closely
4. **Set up billing alerts** for unexpected costs
5. **Regular resource cleanup** in staging

## 🔒 Security Considerations

### Post-Deployment Security Hardening

```bash
# Restrict SSH access to specific IPs
# Update ssh_allowed_cidrs in terraform.tfvars
ssh_allowed_cidrs = ["YOUR.IP.ADDRESS/32"]

# Rotate API tokens regularly
# Update api_tokens in terraform.tfvars

# Monitor access logs for unusual activity
aws logs filter-log-events \
    --log-group-name /aws/application/humansa-production \
    --filter-pattern "ERROR"
```

### Security Monitoring

1. **Enable AWS CloudTrail** for API auditing
2. **Set up AWS Config** for compliance monitoring
3. **Use AWS Security Hub** for centralized security findings
4. **Regular security patches** via automated updates

## 📞 Troubleshooting

### Getting Help

1. **Check CloudWatch Logs** first for application issues
2. **Review Terraform state** for infrastructure issues
3. **Consult AWS documentation** for service-specific problems
4. **Create GitHub Issues** for infrastructure bugs

### Emergency Procedures

#### Infrastructure Failure
```bash
# Scale up quickly if needed
terraform apply -var max_instances=8 -var desired_instances=6

# Rollback to previous state if necessary
terraform state list
terraform import [resource] [id]  # if needed
```

#### Database Issues
```bash
# Create manual snapshot
aws rds create-db-snapshot \
    --db-instance-identifier humansa-production-db \
    --db-snapshot-identifier emergency-backup-$(date +%Y%m%d-%H%M%S)

# Scale database if needed (requires downtime)
terraform apply -var db_instance_class=db.t3.medium
```

---

**Next Steps**: Once deployed, see [OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md) for ongoing maintenance and monitoring procedures.