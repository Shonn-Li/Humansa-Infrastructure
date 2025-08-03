# Humansa Infrastructure Deployment Plan

## Overview
This document outlines the complete deployment plan for Humansa infrastructure based on YouWoAI's architecture.

## Current State Analysis

### Existing Humansa Infrastructure
- **Region**: ap-east-1 (Hong Kong)
- **Components**:
  - ML Server on EC2 with Auto Scaling Group
  - Application Load Balancer
  - RDS PostgreSQL database
  - VPC with public/private subnets
  - SSM Parameter Store for secrets
  - CloudWatch monitoring

### Missing Components (compared to YouWoAI)
1. **Backend API Server** (NestJS)
   - Not yet implemented in Terraform
   - Need ECS/EC2 setup similar to YouWoAI

2. **Frontend Hosting**
   - No S3 bucket for static hosting
   - No CloudFront distribution
   - No Route53 records for web access

3. **Container Registry**
   - No ECR repositories defined
   - Need for both backend and ML server images

4. **CI/CD Pipeline**
   - Basic GitHub Actions for ML server
   - Need comprehensive workflows for all components

## Deployment Architecture

### Phase 1: Core Infrastructure (Current)
✅ VPC and Networking
✅ RDS Database
✅ ML Server with ALB
✅ Basic monitoring

### Phase 2: Backend Services (To Implement)
- [ ] ECR repositories for containers
- [ ] ECS cluster for backend API
- [ ] Backend ALB and target groups
- [ ] API Gateway (optional)

### Phase 3: Frontend Services
- [ ] S3 buckets for static hosting
- [ ] CloudFront distribution
- [ ] Route53 DNS records
- [ ] SSL certificates

### Phase 4: Complete CI/CD
- [ ] GitHub Actions for all services
- [ ] Automated testing
- [ ] Blue-green deployments
- [ ] Rollback procedures

## Execution Steps

### Prerequisites
1. AWS CLI configured with credentials
2. Terraform installed (v1.0+)
3. GitHub repository access
4. Route53 hosted zone for domain

### Step 1: Prepare Secrets
```bash
# Run the setup-secrets script
./setup-secrets.sh
```

### Step 2: Initialize Terraform
```bash
terraform init
terraform workspace new production
terraform workspace select production
```

### Step 3: Plan Infrastructure
```bash
./terraform-plan.sh
```

### Step 4: Apply Infrastructure
```bash
./terraform-apply.sh
```

### Step 5: Deploy Applications
```bash
# Trigger GitHub Actions
./deploy.sh
```

## Security Considerations

1. **Secrets Management**
   - All secrets in SSM Parameter Store
   - IAM roles for service access
   - No hardcoded credentials

2. **Network Security**
   - Private subnets for databases
   - Security groups with minimal access
   - ALB with WAF (to implement)

3. **Data Protection**
   - Encrypted RDS storage
   - S3 bucket encryption
   - TLS for all communications

## Monitoring & Alerts

1. **CloudWatch Dashboards**
   - CPU/Memory metrics
   - Request latency
   - Error rates

2. **Alarms**
   - High CPU usage
   - Database connections
   - ALB unhealthy targets

## Rollback Strategy

1. **Terraform State**
   - Remote state in S3
   - State locking with DynamoDB
   - Versioned state files

2. **Application Rollback**
   - Previous Docker images in ECR
   - GitHub Actions rollback workflow
   - Database migration rollback scripts

## Cost Optimization

1. **Auto Scaling**
   - Scale down during low usage
   - Spot instances for non-critical workloads

2. **Reserved Instances**
   - RDS reserved instances
   - EC2 savings plans

3. **Resource Tagging**
   - Cost allocation tags
   - Environment tags
   - Project tags

## Next Steps

1. Review and approve this plan
2. Set up AWS credentials and permissions
3. Configure terraform.tfvars with actual values
4. Execute deployment in phases
5. Validate each component before proceeding