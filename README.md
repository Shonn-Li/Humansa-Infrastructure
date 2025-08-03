# Humansa Infrastructure

Terraform configuration for deploying Humansa ML API service in AWS Asia regions.

## Architecture Overview

- **Region**: ap-east-1 (Hong Kong) - closest AWS region to mainland China
- **ML Server**: Auto-scaling group with API token authentication
- **Database**: RDS PostgreSQL with read replicas for high availability
- **Security**: HTTPS termination at ALB, API token validation
- **Domain**: humansa.youwo.ai

## Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.0
3. Domain delegation for humansa.youwo.ai
4. API tokens for authentication

## Deployment

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply configuration
terraform apply -var-file="terraform.tfvars"
```

## Infrastructure Components

- VPC with public/private subnets across 2 AZs
- Application Load Balancer with HTTPS
- Auto Scaling Group (2-4 instances)
- RDS PostgreSQL (Multi-AZ)
- ElastiCache Redis cluster
- Systems Manager Parameter Store for secrets
- CloudWatch monitoring and alarms

## Cost Estimates (Monthly - Hong Kong Region)

### Compute
- EC2 Instances (2x t3.medium @ $0.0464/hr): ~$67/month
- Auto Scaling (up to 4 instances peak): ~$134/month max

### Database
- RDS PostgreSQL (db.t3.medium @ $0.118/hr): ~$85/month
- Storage (20GB gp3 + backups): ~$5/month

### Networking & Load Balancing
- Application Load Balancer: ~$30/month
- NAT Gateway (2x @ $0.059/hr): ~$85/month
- Data Processing (ALB): ~$10/month (estimated)

### Caching
- ElastiCache Redis (1x cache.t3.micro): ~$15/month

### Storage & Logs
- S3 (ALB logs, backups): ~$5/month
- CloudWatch Logs: ~$10/month

### Data Transfer (Estimated for 300-400 concurrent requests)
- Outbound to Internet: ~$50-100/month (varies by usage)
- Inter-AZ transfer: ~$10/month

### Monitoring
- CloudWatch Metrics & Alarms: ~$10/month

### **Total Estimated Costs**:
- **Base Configuration (2 instances)**: ~$317/month
- **Peak Load (4 instances)**: ~$384/month
- **Plus Data Transfer**: $50-100/month

### Cost Optimization Recommendations:
1. Use Reserved Instances for base capacity (save ~30%)
2. Consider using t3a instances (AMD) for additional 10% savings
3. Use CloudFront for caching if serving static content
4. Monitor actual usage and downsize if possible