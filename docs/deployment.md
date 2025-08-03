# Humansa Infrastructure Deployment Guide

## Pre-Deployment Setup

### 1. Create Terraform State Backend

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
    --bucket humansa-terraform-state \
    --region ap-east-1 \
    --create-bucket-configuration LocationConstraint=ap-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket humansa-terraform-state \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket humansa-terraform-state \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name humansa-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region ap-east-1
```

### 2. Generate API Tokens

Generate secure API tokens for authentication:

```bash
# Generate 3 secure tokens
for i in {1..3}; do
    openssl rand -base64 32
done
```

### 3. Create SSH Key Pair

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f humansa-key -C "humansa@youwo.ai"
```

### 4. Configure DNS

Ensure you have access to the Route53 hosted zone for `youwo.ai` and note the Zone ID.

## Deployment Steps

### 1. Clone and Configure

```bash
# Clone the infrastructure repository
git clone https://github.com/youwoai/humansa-infrastructure.git
cd humansa-infrastructure

# Copy example variables
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

Update the file with your actual values:
- Database passwords
- Route53 zone ID
- API tokens
- GitHub PAT
- SSH public key
- Alarm email

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan -var-file="terraform.tfvars"
```

### 5. Apply the Configuration

```bash
terraform apply -var-file="terraform.tfvars"
```

## Post-Deployment

### 1. Verify Deployment

```bash
# Check ALB health
curl -I https://humansa.youwo.ai/health

# Check CloudWatch dashboard
terraform output cloudwatch_dashboard_url
```

### 2. Configure API Tokens

The API tokens are stored in AWS Systems Manager Parameter Store. Your application should retrieve them at startup.

### 3. Set Up Monitoring

1. Confirm SNS email subscription for alarms
2. Review CloudWatch dashboard
3. Test alarm notifications

### 4. Security Hardening

1. Restrict SSH access in security groups
2. Enable AWS Config for compliance monitoring
3. Set up AWS CloudTrail for audit logging
4. Review and tighten IAM permissions

## Maintenance

### Updating Infrastructure

```bash
# Pull latest changes
git pull

# Plan changes
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars"
```

### Scaling

To adjust capacity:

```bash
# Update variables in terraform.tfvars
min_instances     = 2
desired_instances = 3
max_instances     = 4

# Apply changes
terraform apply -var-file="terraform.tfvars" -target=aws_autoscaling_group.ml_server
```

### Backup and Restore

RDS automated backups are configured with 30-day retention. For manual backups:

```bash
# Create manual snapshot
aws rds create-db-snapshot \
    --db-instance-identifier humansa-production-db \
    --db-snapshot-identifier humansa-manual-$(date +%Y%m%d-%H%M%S) \
    --region ap-east-1
```

## Continuous Deployment

Humansa uses GitHub Actions for automated deployment, similar to YouWoAI.

### Setting Up Continuous Deployment

1. **Configure GitHub Secrets** in your repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `SLACK_WEBHOOK` (optional)

2. **Set Environment Variable**:
   ```bash
   export GITHUB_PAT="your-github-pat-token"
   ```

3. **Deploy Commands**:
   ```bash
   # Deploy latest changes
   ./deploy.sh deploy

   # Restart services (no code changes)
   ./deploy.sh restart

   # Rollback to previous version
   ./deploy.sh rollback
   ```

### How Deployment Works

1. **deploy.sh** triggers a GitHub Actions workflow via repository dispatch
2. The workflow builds a new Docker image (if deploying)
3. Uses AWS Systems Manager to update all EC2 instances
4. Performs health checks on the ALB
5. Sends Slack notification on completion

### Manual Instance Deployment

If you need to manually deploy to a specific instance:

```bash
# Get instance IDs
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names humansa-production-ml-asg \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
  --output table

# Deploy to specific instance
aws ssm send-command \
  --instance-ids "i-1234567890abcdef0" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "docker pull ghcr.io/youwoai/humansa-ml-server:latest",
    "docker stop humansa-ml || true",
    "docker rm humansa-ml || true",
    "docker run -d --name humansa-ml --restart unless-stopped -p 5000:5000 -v /var/log/humansa-ml:/app/logs -e AWS_REGION=ap-east-1 -e ENVIRONMENT=production ghcr.io/youwoai/humansa-ml-server:latest"
  ]'
```

## Troubleshooting

### Common Issues

1. **ALB Health Check Failures**
   - Check application logs in CloudWatch
   - Verify security group rules
   - Test health endpoint directly on instances

2. **High Latency**
   - Review CloudWatch metrics
   - Check for database connection pooling
   - Verify Redis cache hit rates

3. **Auto Scaling Issues**
   - Review scaling policies
   - Check CloudWatch alarms
   - Verify IAM permissions

4. **Deployment Failures**
   - Check GitHub Actions workflow logs
   - Verify AWS credentials are correct
   - Check EC2 instance logs via SSM Session Manager
   - Verify Docker image builds successfully locally

### Monitoring Deployment

1. **GitHub Actions**: https://github.com/youwoai/humansa-ml-server/actions
2. **CloudWatch Logs**: Check `/aws/application/humansa-production` log group
3. **ALB Health**: Monitor target group health in AWS Console
4. **Application Logs**: Available in CloudWatch Logs

### Support

For issues, contact:
- Infrastructure: infrastructure@youwo.ai
- Application: humansa-support@youwo.ai