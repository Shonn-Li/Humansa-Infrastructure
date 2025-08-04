# Humansa Infrastructure Cost Analysis - Optimized

## Overview
This document provides a detailed cost breakdown for the optimized Humansa ML server infrastructure deployed in AWS Asia Pacific (Hong Kong) region.

## Monthly Cost Breakdown

### Compute (EC2)
- **Instance Type**: t3.medium (2 vCPU, 4GB RAM)
- **Quantity**: 2 instances (minimum)
- **Cost**: $0.0528/hour × 24 hours × 30 days × 2 = **$76.03/month**

### Database (RDS PostgreSQL)
- **Instance Type**: db.t3.small (2 vCPU, 2GB RAM)
- **Multi-AZ**: Disabled
- **Storage**: 20GB gp3 (auto-scaling to 250GB)
- **Cost**: $0.0344/hour × 730 hours = **$25.11/month**
- **Storage**: $0.132/GB × 20GB = **$2.64/month**
- **Total RDS**: **$27.75/month**

### Load Balancer (ALB)
- **ALB Hours**: $0.0272/hour × 730 hours = **$19.86/month**
- **LCU Usage**: ~$5/month (estimated for 300-400 concurrent connections)
- **Total ALB**: **$24.86/month**

### Network & Data Transfer
- **Internet Gateway**: Free
- **Data Transfer**: ~100GB/month × $0.12/GB = **$12/month**
- **No NAT Gateways**: **$0/month** (saved $85.87/month)

### Storage & Backups
- **EBS Volumes**: 100GB × 2 × $0.10/GB = **$20/month**
- **RDS Snapshots**: ~20GB × $0.095/GB = **$1.90/month**
- **Total Storage**: **$21.90/month**

### Monitoring & Logs
- **CloudWatch Metrics**: ~$3/month
- **CloudWatch Logs**: ~$2/month
- **Total Monitoring**: **$5/month**

## Total Monthly Cost

| Component | Cost |
|-----------|------|
| EC2 Instances | $76.03 |
| RDS Database | $27.75 |
| Load Balancer | $24.86 |
| Data Transfer | $12.00 |
| Storage | $21.90 |
| Monitoring | $5.00 |
| **TOTAL** | **$167.54/month** |

## Daily Cost
**$167.54 ÷ 30 = $5.58/day**

## Comparison with Original Design

### Original Infrastructure
- Total: $303.18/month ($10.11/day)
- Included: NAT Gateways ($85.87), Redis ($36), larger instances

### Optimized Infrastructure
- Total: $167.54/month ($5.58/day)
- Removed: NAT Gateways, Redis
- Rightsized: Database (db.t3.small), kept t3.medium for compute

### Savings
- **Monthly Savings**: $135.64 (44.7% reduction)
- **Annual Savings**: $1,627.68

## Cost Optimization Strategies Implemented

1. **Removed NAT Gateways** (-$85.87/month)
   - EC2 instances use public IPs with security groups
   - No functional impact for stateless API servers

2. **Removed Redis** (-$36/month)
   - Stateless API doesn't require caching
   - Authentication uses API tokens (no sessions)

3. **Rightsized Database** (-$13/month)
   - db.t3.small sufficient for embeddings storage
   - 23k appointments/month is low volume

4. **Kept Appropriate Compute** (no change)
   - t3.medium already optimal for ML workloads
   - 2 instances provide redundancy

## Scaling Costs

If traffic increases:
- **+1 EC2 instance**: +$38.02/month
- **Upgrade to db.t3.medium**: +$13/month
- **Increased data transfer**: +$0.12/GB

## Reserved Instance Savings (Optional)

1-year commitment could save:
- EC2: ~25% ($19/month)
- RDS: ~27% ($7.50/month)
- Total potential: **$26.50/month additional savings**

## Conclusion

The optimized infrastructure provides the same functionality at 44.7% lower cost:
- Maintains high availability with 2 EC2 instances
- Provides secure database storage
- Handles 300-400 concurrent requests
- Supports auto-scaling for traffic spikes

This configuration follows the cost-efficient patterns observed in YouWoAI's infrastructure while providing all required features for the Humansa ML API service.