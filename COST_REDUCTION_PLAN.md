# Humansa Infrastructure Cost Reduction Plan

## Current vs Optimized Costs

### Current Setup (~$150-170/month)
- **EC2**: 2 × t3.medium (4GB RAM) = $74/month
- **RDS**: 1 × db.t3.small (2GB RAM) = $25/month
- **ALB**: Load balancer = $20-30/month
- **Storage**: 200GB EBS + backups = $20-40/month

### Optimized Setup (~$58/month) - 65% REDUCTION
- **EC2**: 1 × t3.small (2GB RAM) = $15/month
- **RDS**: 1 × db.t3.micro (1GB RAM) = $13/month
- **ALB**: Load balancer = $20/month
- **Storage**: 30GB EBS + minimal backups = $10/month

## Implementation Steps

### Step 1: Apply Cost-Optimized Configuration
```bash
cd environments/production

# First, create a backup of current state
terraform state pull > terraform.state.backup.json

# Plan with cost-optimized values
terraform plan -var-file="cost-optimized.tfvars"

# Apply the changes
terraform apply -var-file="cost-optimized.tfvars"
```

### Step 2: Verify Reduced Resources
```bash
# Check new instance types
aws ec2 describe-instances --filters "Name=tag:Project,Values=humansa" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType]'

# Check RDS instance
aws rds describe-db-instances --db-instance-identifier humansa-production-db \
  --query 'DBInstances[0].DBInstanceClass'
```

### Step 3: Monitor Performance
After downgrading, monitor for 24-48 hours:
- Response times
- Memory usage
- CPU utilization
- Database connections

## Performance Considerations

### With t3.small (2GB RAM):
- **Suitable for**: 
  - Development/testing
  - Low-traffic production (< 100 concurrent users)
  - Basic AI inference tasks
  
- **Limitations**:
  - Memory-intensive operations may fail
  - Slower response times under load
  - Limited concurrent request handling

### With db.t3.micro (1GB RAM):
- **Suitable for**:
  - Small datasets (< 10GB)
  - Light query load
  - Development environments

- **Limitations**:
  - Connection pool must be smaller
  - Complex queries may timeout
  - No Performance Insights

## Rollback Plan

If performance is unacceptable:
```bash
# Remove the -var-file flag to use defaults
terraform apply
```

## Further Cost Reductions (if needed)

### Option 1: Remove ALB (-$20/month)
Use a single EC2 instance with Elastic IP:
```hcl
# In cost-optimized.tfvars add:
use_alb = false  # Requires code changes
```

### Option 2: Spot Instances (-30% more)
```hcl
# Use spot instances for ML servers
use_spot_instances = true
spot_max_price = "0.0256"  # 50% of on-demand
```

### Option 3: Schedule-Based Scaling
Turn off instances during non-business hours:
```bash
# Scale down at night (saves ~50% more)
aws autoscaling put-scheduled-action \
  --auto-scaling-group-name humansa-production-ml-asg \
  --scheduled-action-name scale-down-night \
  --recurrence "0 22 * * *" \
  --min-size 0 --desired-capacity 0
```

## Monitoring Costs

Check AWS Cost Explorer weekly:
```bash
# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --filter file://humansa-cost-filter.json
```

## Emergency Teardown

If costs need to be reduced to $0 immediately:
```bash
# Set all counts to 0
terraform apply -var="min_instances=0" -var="desired_instances=0"

# Or destroy everything (CAUTION: Data loss!)
terraform destroy
```

## Recommendations

1. **Start with the cost-optimized configuration** - This gives 65% savings
2. **Monitor for 48 hours** - Ensure performance is acceptable
3. **Further optimize if needed** - Remove ALB or use spot instances
4. **Set up billing alerts** - Get notified if costs exceed $75/month
5. **Consider time-based scaling** - Turn off during nights/weekends

The optimized setup should handle light to moderate Humansa agent workloads while keeping costs under $60/month.