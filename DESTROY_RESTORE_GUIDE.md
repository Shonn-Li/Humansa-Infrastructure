# Humansa Infrastructure - Destroy & Restore Guide

## Overview
This guide explains how to temporarily destroy the Humansa infrastructure to save costs and restore it when needed.

## Cost Savings
- **Running Cost**: ~$40-45/month
- **Destroyed Cost**: ~$5-10/month (only S3, snapshots, and Route53)
- **Savings**: ~$30-35/month when destroyed

## Destruction Process

### Method 1: GitHub Actions UI (Recommended)
1. Go to: https://github.com/Shonn-Li/Humansa-Infrastructure/actions
2. Click "Destroy Infrastructure" workflow
3. Click "Run workflow"
4. Enter confirmation text: `DESTROY-HUMANSA`
5. Choose whether to backup database (recommended: yes)
6. Click "Run workflow"

### Method 2: Git Tag
```bash
# Create and push destroy tag
git tag destroy-$(date +%Y%m%d-%H%M%S)
git push origin destroy-$(date +%Y%m%d-%H%M%S)
```

### What Gets Destroyed
- ✅ All EC2 instances
- ✅ Auto Scaling Groups
- ✅ Load Balancer
- ✅ Target Groups
- ✅ RDS database instance
- ✅ Security Groups
- ✅ VPC resources (subnets, routes, etc.)

### What Gets Preserved
- ✅ Database snapshot (automatic backup)
- ✅ Terraform state backup in S3
- ✅ SSM parameters
- ✅ Route53 hosted zone
- ✅ SSL certificate
- ✅ S3 buckets
- ✅ GitHub secrets

### Destruction Timeline
- Database backup: ~5-10 minutes
- Infrastructure destruction: ~10-15 minutes
- Total time: ~15-25 minutes

## Restoration Process

### Method 1: GitHub Actions UI (Recommended)
1. Go to: https://github.com/Shonn-Li/Humansa-Infrastructure/actions
2. Click "Restore Infrastructure" workflow
3. Click "Run workflow"
4. Optional: Enter snapshot ID to restore database from backup
5. Choose configuration (cost-optimized: yes)
6. Click "Run workflow"

### Method 2: Git Tag
```bash
# Create and push restore tag
git tag restore-$(date +%Y%m%d-%H%M%S)
git push origin restore-$(date +%Y%m%d-%H%M%S)
```

### Restoration Timeline
- Infrastructure creation: ~15-20 minutes
- Database restoration (if from snapshot): ~10-15 minutes
- ML server deployment: ~5-10 minutes
- Total time: ~30-45 minutes

## Database Backup Management

### List Available Snapshots
```bash
aws rds describe-db-snapshots \
  --query "DBSnapshots[?contains(DBSnapshotIdentifier, 'humansa')].{ID:DBSnapshotIdentifier,Created:SnapshotCreateTime,Size:AllocatedStorage}" \
  --output table
```

### Create Manual Snapshot
```bash
aws rds create-db-snapshot \
  --db-instance-identifier humansa-postgres \
  --db-snapshot-identifier humansa-manual-$(date +%Y%m%d-%H%M%S)
```

### Delete Old Snapshots
```bash
# Delete snapshots older than 30 days
aws rds describe-db-snapshots \
  --query "DBSnapshots[?SnapshotCreateTime<'$(date -d '30 days ago' --iso-8601)'].DBSnapshotIdentifier" \
  --output text | xargs -n1 aws rds delete-db-snapshot --db-snapshot-identifier
```

## Quick Commands

### Check Infrastructure Status
```bash
# Check if infrastructure exists
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=humansa" \
  --query "Reservations[].Instances[?State.Name=='running'].InstanceId" \
  --output text

# If output is empty, infrastructure is destroyed
```

### Emergency Destroy (Manual)
```bash
cd environments/production
terraform init
terraform destroy -auto-approve
```

### Emergency Restore (Manual)
```bash
cd environments/production
terraform init
terraform apply -var-file="ultra-cost-optimized.tfvars" -auto-approve
```

## Cost Optimization Tips

### When to Destroy
- Development/testing complete for the day
- Weekend or holidays
- No active development for >24 hours
- Budget constraints

### When NOT to Destroy
- Active development in progress
- Production deployment imminent
- Database has recent critical data not backed up
- Team members actively testing

## Automation Ideas

### Daily Schedule (Cron)
Add to GitHub Actions for automatic destroy/restore:
```yaml
on:
  schedule:
    # Destroy at 8 PM PST daily
    - cron: '0 4 * * *'  # 4 AM UTC = 8 PM PST
    
  workflow_dispatch:
```

### Weekend Destruction
```yaml
on:
  schedule:
    # Destroy Friday 6 PM PST
    - cron: '0 2 * * 6'  # Saturday 2 AM UTC
    # Restore Monday 6 AM PST
    - cron: '0 14 * * 1'  # Monday 2 PM UTC
```

## Troubleshooting

### Destruction Fails
1. Check CloudFormation stacks for dependencies
2. Manually delete stuck resources:
   ```bash
   # Force delete ALB
   aws elbv2 delete-load-balancer --load-balancer-arn <arn>
   
   # Force terminate instances
   aws ec2 terminate-instances --instance-ids <instance-id>
   ```

### Restoration Fails
1. Check terraform state:
   ```bash
   terraform state list
   terraform state rm <problematic-resource>
   ```
2. Restore from S3 backup:
   ```bash
   aws s3 cp s3://humansa-terraform-state/backups/<backup-file> terraform.tfstate
   ```

### Database Issues
1. Check snapshot status:
   ```bash
   aws rds describe-db-snapshots --db-snapshot-identifier <snapshot-id>
   ```
2. Restore to new instance:
   ```bash
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier humansa-postgres-new \
     --db-snapshot-identifier <snapshot-id>
   ```

## Safety Features

### Destruction Protection
- ✅ Requires explicit confirmation text
- ✅ Automatic database backup
- ✅ State file backup to S3
- ✅ Restoration instructions saved
- ✅ Cannot accidentally trigger

### Restoration Protection
- ✅ Checks for existing infrastructure
- ✅ Preserves current database if exists
- ✅ Updates all SSM parameters
- ✅ Verifies successful creation

## Monitoring

### Check Costs
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter file://cost-filter.json
```

### Set Budget Alerts
```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

## Best Practices

1. **Always backup before destroy** - Database snapshots are cheap insurance
2. **Document destruction reason** - Use meaningful tag names
3. **Test restoration regularly** - Ensure process works smoothly
4. **Monitor costs** - Track savings from destruction periods
5. **Communicate with team** - Notify before destroying shared resources
6. **Automate when possible** - Use scheduled workflows for predictable patterns

## Recovery Scenarios

### Scenario 1: Accidental Destruction
1. Check S3 for state backup
2. Find latest database snapshot
3. Run restore workflow with snapshot ID
4. Verify all services operational

### Scenario 2: Partial Destruction
1. Run `terraform plan` to see what's missing
2. Apply only missing resources
3. Update SSM parameters if needed
4. Redeploy ML server

### Scenario 3: Complete Fresh Start
1. Run restore workflow without snapshot ID
2. Creates new empty database
3. Deploy ML server fresh
4. Restore data from application backups

## Support

For issues or questions:
- Check workflow logs in GitHub Actions
- Review CloudWatch logs
- Check terraform state status
- Contact team lead for assistance