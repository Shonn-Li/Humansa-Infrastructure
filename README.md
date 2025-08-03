# Humansa Infrastructure

A well-organized, modular Terraform configuration for deploying Humansa ML API service in AWS Asia regions using infrastructure as code best practices.

## 🏗️ Architecture Overview

- **Region**: ap-east-1 (Hong Kong) - closest AWS region to mainland China
- **ML Server**: Auto-scaling group with API token authentication
- **Database**: RDS PostgreSQL with optimized configuration
- **Security**: HTTPS termination at ALB, API token validation, security groups
- **Domain**: humansa.youwo.ai (production) / humansa-staging.youwo.ai (staging)
- **Monitoring**: CloudWatch alarms and logging with SNS notifications

## 📁 Project Structure

```
├── environments/           # Environment-specific configurations
│   ├── production/        # Production environment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── staging/           # Staging environment (cost-optimized)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── modules/               # Reusable Terraform modules
│   ├── networking/        # VPC, subnets, routing
│   ├── security/          # Security groups
│   ├── load-balancer/     # ALB, SSL certificates, Route53
│   ├── database/          # RDS PostgreSQL with monitoring
│   ├── compute/           # Auto Scaling Groups, EC2 instances
│   └── monitoring/        # CloudWatch alarms, SNS
├── scripts/               # Deployment and management scripts
├── docs/                  # Documentation and guides
└── README.md
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform >= 1.0** installed
3. **AWS CLI** configured with credentials
4. **Domain control** for youwo.ai with Route53 hosted zone
5. **GitHub repository** with Humansa ML server code

### 1. Initial Setup

```bash
# Clone the repository
git clone https://github.com/Shonn-Li/Humansa-Infrastructure.git
cd Humansa-Infrastructure

# Initialize Terraform backend (first time only)
cd environments/production
terraform init
```

### 2. Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your actual values
nano terraform.tfvars
```

**Required Variables:**
- `db_username` & `db_password` - Database credentials
- `route53_zone_id` - Your youwo.ai hosted zone ID
- `api_tokens` - Array of secure API tokens
- `github_pat` - GitHub Personal Access Token
- `ssh_public_key` - Your SSH public key
- `alarm_email` - Email for CloudWatch alerts

### 3. Deploy Infrastructure

```bash
# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply configuration
terraform apply -var-file="terraform.tfvars"
```

### 4. Verify Deployment

```bash
# Check outputs
terraform output

# Test API endpoint
curl -H "Authorization: Bearer YOUR_API_TOKEN" https://humansa.youwo.ai/health
```

## 🏭 Environment Differences

### Production Environment
- **Instances**: 2-4 x t3.medium
- **Database**: db.t3.small with 30-day backups
- **Storage**: 100GB root volumes
- **Monitoring**: Full CloudWatch integration
- **Security**: Deletion protection enabled
- **Cost**: ~$175-242/month

### Staging Environment
- **Instances**: 1-2 x t3.small
- **Database**: db.t3.micro with 7-day backups
- **Storage**: 50GB root volumes
- **Monitoring**: Basic monitoring only
- **Security**: Deletion protection disabled
- **Cost**: ~$50-80/month

## 💰 Cost Optimization

This infrastructure has been optimized to save **$142/month** compared to the original design:

### Optimizations Applied
- ✅ **Removed NAT Gateways** - $85/month saved
  - Uses public subnets with security groups (following YouWoAI pattern)
- ✅ **Removed Redis Cache** - $15/month saved
  - Stateless ML API doesn't need caching layer
- ✅ **Downsized RDS** - $42/month saved
  - db.t3.small sufficient for 300-400 concurrent requests

### Monthly Costs (Hong Kong Region)
```
Production Environment:
├── EC2 Instances (2x t3.medium): ~$67/month
├── RDS PostgreSQL (db.t3.small): ~$43/month
├── Application Load Balancer: ~$30/month
├── Storage & Logs: ~$15/month
├── CloudWatch & Monitoring: ~$10/month
├── Data Transfer: ~$10/month
└── Total: ~$175/month base, ~$242/month peak
```

## 🛡️ Security Features

- **HTTPS Only**: Automatic HTTP to HTTPS redirects
- **API Token Authentication**: Multiple secure tokens supported
- **Security Groups**: Least privilege access controls
- **Encrypted Storage**: All EBS volumes and RDS encrypted
- **VPC Isolation**: Private database subnets
- **Parameter Store**: Secure secret management
- **IMDSv2**: Enhanced EC2 metadata security

## 📊 Monitoring & Alerting

### CloudWatch Alarms
- **High CPU Usage** (>75%) - Triggers scale-up
- **Low CPU Usage** (<25%) - Triggers scale-down
- **Database CPU** (>80%) - Email alert
- **Database Storage** (<10GB) - Email alert
- **Database Connections** (>80) - Email alert
- **ALB Unhealthy Targets** - Email alert
- **High Response Time** (>5s) - Email alert

### Logging
- **Application Logs**: CloudWatch Logs with 30-day retention
- **ALB Access Logs**: S3 bucket with lifecycle management
- **System Metrics**: CloudWatch agent on all instances

## 🔧 Operations

### Scaling
- **Auto Scaling**: Automatic based on CPU utilization
- **Manual Scaling**: Update desired capacity in Terraform
- **Zero Downtime**: Rolling deployments via Auto Scaling Group

### Deployments
- **GitHub Actions**: Automated CI/CD pipeline
- **Container Registry**: GitHub Container Registry (ghcr.io)
- **Health Checks**: ALB health checks ensure availability
- **Rollback**: Previous launch template versions available

### Maintenance
- **Database Backups**: Automated daily backups
- **System Updates**: Automated via user data script
- **SSL Certificates**: Auto-renewal via AWS Certificate Manager
- **Log Rotation**: Automatic cleanup via S3 lifecycle policies

## 🌍 Multi-Region Considerations

Currently deployed in **ap-east-1 (Hong Kong)** for optimal China performance.

### Future Expansion Options
- **ap-southeast-1** (Singapore) - Southeast Asia
- **ap-northeast-1** (Tokyo) - Japan/Korea
- **CloudFront CDN** - Global edge caching

## 📚 Additional Resources

- **[Setup Guide](docs/SETUP_GUIDE.md)** - Detailed deployment instructions
- **[Security Documentation](docs/SECRETS_DOCUMENTATION.md)** - Secret management
- **[Deployment Guide](docs/deployment.md)** - CI/CD and operations
- **[Cost Analysis](docs/CURRENT_INFRASTRUCTURE_EVALUATION.md)** - Detailed cost breakdown

## 🤝 Contributing

1. Create feature branch from `main`
2. Make changes in appropriate module
3. Test in staging environment first
4. Submit PR with detailed description
5. Deploy to production after approval

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Shonn-Li/Humansa-Infrastructure/issues)
- **Monitoring**: CloudWatch dashboard and SNS alerts
- **Documentation**: Comprehensive guides in `/docs`

---

**Note**: This infrastructure is designed for production workloads handling 300-400 concurrent requests with high availability and security standards.