# Humansa Infrastructure Components Detail

## What Each Component Does

### 1. Network Components (network.tf)

#### VPC (Virtual Private Cloud)
- **What**: Your private network in AWS
- **Current**: 10.100.0.0/16 (65,536 IPs)
- **Cost**: Free
- **Needed**: ✅ YES

#### Subnets
- **What**: Network segments across availability zones
- **Current**: 
  - 2 public subnets (for ALB)
  - 2 private subnets (for EC2)
  - 2 database subnets (for RDS)
- **Cost**: Free
- **Needed**: ✅ YES (but simplify to just public)

#### NAT Gateways ❌
- **What**: Allows private instances to reach internet
- **Current**: 2x NAT Gateways
- **Cost**: $85/month
- **Needed**: ❌ NO - Put instances in public subnets

#### Internet Gateway
- **What**: Connects VPC to internet
- **Current**: 1x IGW
- **Cost**: Free
- **Needed**: ✅ YES

### 2. Compute Components (ml_server.tf)

#### EC2 Instances
- **What**: Virtual servers running your ML code
- **Current**: 
  - Instance type: t3.medium (2 vCPU, 4GB RAM)
  - Auto Scaling: 2-4 instances
  - Storage: 100GB each
- **Cost**: $67/month (2 instances)
- **Needed**: ✅ YES

#### Auto Scaling Group
- **What**: Automatically adds/removes instances based on load
- **Current**: Min 2, Max 4 instances
- **Cost**: Free (pay for instances)
- **Needed**: ✅ YES

#### Launch Template
- **What**: Configuration for new instances
- **Current**: Includes user data script for deployment
- **Cost**: Free
- **Needed**: ✅ YES

### 3. Database Components (database.tf)

#### RDS PostgreSQL
- **What**: Managed database service
- **Current**:
  - db.t3.medium (2 vCPU, 4GB RAM)
  - 20GB storage (auto-scales to 250GB)
  - Single AZ
  - 30-day backups
- **Cost**: $85/month
- **Recommendation**: Downsize to db.t3.small ($42/month)
- **Needed**: ✅ YES

### 4. Caching Components (redis.tf) ❌

#### ElastiCache Redis
- **What**: In-memory cache/session store
- **Current**: 
  - cache.t3.micro
  - Single node
- **Cost**: $15/month
- **Use cases**:
  - Session storage (you use API tokens)
  - Query caching (minimal benefit for ML)
  - Rate limiting (can do in app)
- **Needed**: ❌ NO

### 5. Load Balancing (alb.tf)

#### Application Load Balancer
- **What**: Distributes traffic, handles HTTPS
- **Current**:
  - Internet-facing
  - HTTPS termination
  - Health checks
- **Cost**: $30/month + data transfer
- **Needed**: ✅ YES

#### Target Group
- **What**: Group of instances to receive traffic
- **Current**: Port 5000, health check on /health
- **Cost**: Free (included in ALB)
- **Needed**: ✅ YES

#### SSL Certificate
- **What**: HTTPS certificate for humansa.youwo.ai
- **Current**: AWS Certificate Manager
- **Cost**: Free
- **Needed**: ✅ YES

### 6. Security Components (security_groups.tf)

#### Security Groups
- **What**: Virtual firewalls for instances
- **Current**:
  - ALB: Allow 80/443 from internet
  - EC2: Allow 5000 from ALB, 22 for SSH
  - RDS: Allow 5432 from EC2
  - Redis: Allow 6379 from EC2
- **Cost**: Free
- **Needed**: ✅ YES

### 7. Monitoring (monitoring.tf)

#### CloudWatch Alarms
- **What**: Alerts for issues
- **Current**: CPU, memory, disk alarms
- **Cost**: ~$10/month
- **Needed**: ✅ YES

#### CloudWatch Logs
- **What**: Application and system logs
- **Current**: 30-day retention
- **Cost**: ~$10/month
- **Needed**: ✅ YES

#### SNS Topic
- **What**: Email notifications for alarms
- **Current**: Sends to alarm_email
- **Cost**: Free (1000 emails/month)
- **Needed**: ✅ YES

### 8. Secrets Management (ssm_parameters.tf)

#### SSM Parameters
- **What**: Secure storage for credentials
- **Current**: Database, Redis, API tokens
- **Cost**: Free (under 10k parameters)
- **Needed**: ✅ YES

### 9. Deployment (user_data.sh, deploy.sh)

#### User Data Script
- **What**: Initializes EC2 instances
- **Current**: Installs Docker, triggers deployment
- **Cost**: Free
- **Needed**: ✅ YES

#### GitHub Actions
- **What**: CI/CD pipeline
- **Current**: Deploys on git push
- **Cost**: Free (public repo)
- **Needed**: ✅ YES (or alternative)

## Summary: What You Actually Need

### Essential Components ✅
1. **VPC + Subnets** (simplified)
2. **EC2 Instances** (t3.medium x2)
3. **RDS PostgreSQL** (downsize to t3.small)
4. **ALB** (for HTTPS)
5. **Security Groups**
6. **SSM Parameters**
7. **Basic Monitoring**

### Remove These ❌
1. **NAT Gateways** (-$85/month)
2. **Redis Cache** (-$15/month)
3. **Complex subnet structure**

### Total Infrastructure
- **Current**: 50+ resources, $302/month
- **Optimized**: ~30 resources, $159/month
- **Savings**: $143/month (47%)

## Architecture Diagram

```
Current (Complex):
Internet → ALB → Private Subnet → NAT Gateway → Internet
              ↓         ↓              ↓
            EC2 → Redis + RDS    (Expensive!)

Simplified (Recommended):
Internet → ALB → Public Subnet → Internet
              ↓         ↓
            EC2  →   RDS     (Simple & Cheap!)
```