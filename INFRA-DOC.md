# Humansa Infrastructure Documentation (INFRA-DOC)

## Current Implementation Status

### Overview
The Humansa infrastructure is designed as a cost-optimized, scalable ML server system deployed in AWS Hong Kong (ap-east-1) region. It follows YouWoAI's deployment patterns but with optimizations for lower operational costs.

### Architecture Components

#### 1. **Networking Module** (`modules/networking/`)
- **VPC**: 10.0.0.0/16 CIDR block
- **Subnets**: 
  - 2 public subnets (10.0.1.0/24, 10.0.2.0/24) for ALB
  - 2 private subnets (10.0.10.0/24, 10.0.20.0/24) for EC2/RDS
- **Internet Gateway**: Direct internet access for public subnets
- **Route Tables**: Separate for public/private subnets
- **Files**: `main.tf`, `variables.tf`, `outputs.tf`

#### 2. **Security Module** (`modules/security/`)
- **ALB Security Group**: Allows inbound 80/443, all outbound
- **EC2 Security Group**: Allows from ALB and SSH from bastion
- **RDS Security Group**: Allows PostgreSQL (5432) from EC2 only
- **Files**: `main.tf`, `variables.tf`, `outputs.tf`

#### 3. **Database Module** (`modules/database/`)
- **RDS PostgreSQL**: db.t3.small instance
- **Engine**: PostgreSQL 15.3
- **Storage**: 100GB gp3 SSD
- **Backup**: 7-day retention
- **Subnet Group**: Spans private subnets
- **Files**: `main.tf`, `variables.tf`, `outputs.tf`

#### 4. **Compute Module** (`modules/compute/`)
- **Launch Template**: t3.medium instances with Amazon Linux 2
- **Auto Scaling Group**: 2-4 instances
- **Target Group**: For ALB routing
- **User Data**: Automated ML server deployment
- **Files**: `main.tf`, `variables.tf`, `outputs.tf`, `user_data.sh`

#### 5. **Load Balancer Module** (`modules/load-balancer/`)
- **Application Load Balancer**: Internet-facing
- **Listeners**: HTTP (80) redirects to HTTPS (443)
- **Target Group**: Routes to EC2 instances on port 5000
- **Health Checks**: /health endpoint
- **Files**: `main.tf`, `variables.tf`, `outputs.tf`

#### 6. **Monitoring Module** (`modules/monitoring/`)
- **CloudWatch Alarms**: CPU, memory, disk usage
- **Log Groups**: Application and system logs
- **Dashboard**: Real-time metrics visualization
- **Files**: `main.tf`, `variables.tf`, `outputs.tf`

### Environment Configuration

#### Production Environment (`environments/production/`)
- **Backend**: S3 state storage with DynamoDB locking
- **Variables**: Environment-specific configurations
- **Provider**: AWS Hong Kong region (ap-east-1)
- **Files**:
  - `main.tf`: Module instantiation
  - `variables.tf`: Input variables
  - `outputs.tf`: Output values
  - `terraform.tfvars.example`: Example configuration

### Scripts (`scripts/`)

#### 1. **terraform-plan.sh**
- Creates Terraform plan
- Uploads plan to S3 bucket
- Used by GitHub Actions for review
- Follows YouWoAI's plan/apply separation pattern

#### 2. **terraform-apply.sh**
- Downloads plan from S3
- Applies approved plan
- Ensures consistency between plan and apply

#### 3. **deploy.sh**
- Full deployment orchestration
- Handles S3 backend setup
- Runs terraform init/plan/apply

### Documentation (`docs/`)

#### 1. **CREDENTIAL_MANAGEMENT_ANALYSIS.md**
- Complete analysis of YouWoAI's credential system
- OIDC vs Access Key comparison
- GitHub Secrets to SSM parameter mapping

#### 2. **TERRAFORM_DEPLOYMENT_STATUS.md**
- Infrastructure build status
- Module completion tracking
- Next steps checklist

#### 3. **OIDC_SETUP_GUIDE.md**
- Step-by-step OIDC configuration
- GitHub Actions integration
- Trust policy setup

### Cost Optimizations Implemented

1. **Removed NAT Gateways**: Saved $90/month
   - EC2 instances use security groups instead
   - Direct internet access through IGW for public resources

2. **No Redis Cluster**: Saved $50/month
   - Stateless ML server design
   - PostgreSQL handles all persistence

3. **Right-sized RDS**: Saved $25/month
   - t3.small sufficient for 300-400 concurrent requests
   - gp3 storage for better price/performance

4. **Optimized EC2**: 
   - t3.medium instances with burstable CPU
   - Auto-scaling 2-4 instances based on load

### Current Progress

✅ **Completed**:
- Full Terraform module structure
- Cost optimization analysis
- Credential management research
- OIDC authentication discovery
- Deployment scripts creation
- Comprehensive documentation
- OIDC role creation for Humansa (arn:aws:iam::992382528744:role/humansa-github-actions-role)
- GitHub Actions workflow files (plan.yml, apply.yml)

🔄 **Ready for Deployment**:
- GitHub repository creation
- GitHub secrets configuration
- First infrastructure deployment

⏳ **Post-Deployment Tasks**:
- SSL certificate configuration
- Domain setup (api.humansa.ai)
- Application deployment (ML server)
- SSM parameters for application secrets

### Key Differences from YouWoAI

1. **No Redis**: Simplified architecture
2. **No NAT Gateways**: Cost reduction
3. **Smaller RDS**: Right-sized for workload
4. **Hong Kong Region**: Optimized for China access
5. **Separate AWS Account**: Complete isolation
6. **SSH Key via Secrets**: More flexible than file-based approach

### Files Tree Structure
```
humansa-infrastructure/
├── environments/
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── modules/
│   ├── networking/
│   ├── security/
│   ├── database/
│   ├── compute/
│   ├── load-balancer/
│   └── monitoring/
├── scripts/
│   ├── deploy.sh
│   ├── terraform-plan.sh
│   └── terraform-apply.sh
├── docs/
│   ├── CREDENTIAL_MANAGEMENT_ANALYSIS.md
│   ├── TERRAFORM_DEPLOYMENT_STATUS.md
│   └── OIDC_SETUP_GUIDE.md
└── .gitignore
```

### Next Immediate Steps

1. Create OIDC identity provider in AWS
2. Create IAM role with OIDC trust policy
3. Set up GitHub repository
4. Configure GitHub secrets
5. Deploy infrastructure## Current Status

✅ **DEPLOYMENT SUCCESSFUL** (v1.0.8):
- Infrastructure fully deployed on 2025-08-05
- All resources created successfully
- Load Balancer: `humansa-production-alb-143869024.ap-east-1.elb.amazonaws.com`
- URL: `https://humansa.youwo.ai`
- Auto-scaling Group: `humansa-production-ml-asg` (2-4 t3.medium instances)
- VPC: `vpc-025e0810859395fc9`
- RDS Database: Successfully created with validated password
- SSL Certificate: Attached to ALB

🔄 **Post-Deployment Tasks**:
1. Deploy ML server application to EC2 instances
2. Configure application secrets in SSM Parameter Store
3. Set up monitoring alerts
4. Verify health check endpoints

✅ **Completed Milestones**:
- GitHub repository created and configured
- OIDC authentication working perfectly
- IAM role with correct trust policy
- SSH key pair generated and stored in GitHub Secrets
- GitHub Actions workflows tested and operational
- Infrastructure deployed with cost optimizations
- Estimated monthly cost: ~$252
