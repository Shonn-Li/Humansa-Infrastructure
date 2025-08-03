# Humansa Deployment Verification Documentation

## Overview

This document explains how the Humansa deployment system works and verifies it follows the same patterns as YouWoAI.

## Deployment Architecture Comparison

### YouWoAI Deployment Method
1. **Trigger**: GitHub API dispatch event from local script
2. **GitHub Actions**: Workflow triggered by repository_dispatch
3. **Deployment**: Uses AWS SSM to send commands to EC2 instances
4. **Container**: Docker pull and run on each instance
5. **Health Check**: Verifies ALB target health after deployment

### Humansa Deployment Method (Identical)
1. **Trigger**: `deploy.sh` sends GitHub API dispatch event
2. **GitHub Actions**: `.github/workflows/deploy.yml` handles the event
3. **Deployment**: AWS SSM sends Docker commands to instances
4. **Container**: Pulls from GitHub Container Registry (ghcr.io)
5. **Health Check**: Checks ALB target group health status

## Key Files

### deploy.sh
```bash
# Triggers GitHub Actions workflow via repository dispatch
curl -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPO/dispatches" \
    -d '{"event_type": "deploy-humansa", ...}'
```

### .github/workflows/deploy.yml
Key sections that match YouWoAI pattern:

1. **Trigger Events**:
   - `deploy-humansa`: Full deployment with new image
   - `restart-humansa`: Restart existing containers
   - `rollback-humansa`: Rollback to previous version
   - `new-ml-instance-created`: Auto-deploy to new instances

2. **Deployment Process**:
   ```yaml
   # Get instances from Auto Scaling Group
   INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups ...)
   
   # Deploy to each instance via SSM
   aws ssm send-command \
     --instance-ids "$INSTANCE_ID" \
     --document-name "AWS-RunShellScript" \
     --parameters 'commands=[
       "docker pull ...",
       "docker stop humansa-ml || true",
       "docker rm humansa-ml || true", 
       "docker run -d --name humansa-ml ..."
     ]'
   ```

3. **Health Verification**:
   ```yaml
   # Check ALB target health
   aws elbv2 describe-target-health \
     --target-group-arn $TARGET_GROUP_ARN
   ```

### user_data.sh (EC2 Instance Bootstrap)
Matches YouWoAI pattern:
1. Installs Docker and AWS CLI
2. Configures CloudWatch agent
3. Triggers GitHub workflow for initial deployment
4. Sets up health check cron job

## Verification Checklist

✅ **GitHub Actions Trigger**
- Uses repository_dispatch like YouWoAI
- Supports multiple event types (deploy, restart, rollback)

✅ **AWS Systems Manager**
- Uses SSM send-command for zero-downtime deployment
- No direct SSH needed

✅ **Docker Deployment**
- Pulls from container registry
- Graceful container replacement (stop, rm, run)
- Uses --restart unless-stopped

✅ **Health Checks**
- ALB target group health verification
- 30-second wait for stability
- Health check endpoint at /health

✅ **Auto Scaling Integration**
- Queries ASG for active instances
- Deploys to all InService instances
- Handles new instance auto-deployment

✅ **Error Handling**
- Uses `|| true` to prevent script failure
- Slack notifications on success/failure
- CloudWatch logging for debugging

## Key Differences from YouWoAI

1. **No S3**: Humansa doesn't use S3 for artifacts
2. **Simpler Architecture**: No separate app/ML server split
3. **Direct Container Registry**: Uses GitHub Container Registry instead of ECR
4. **API Token Auth**: Uses tokens instead of JWT

## Security Considerations

1. **Secrets Management**:
   - GitHub PAT stored as environment variable
   - API tokens in Parameter Store
   - Database credentials in Parameter Store

2. **Network Security**:
   - Instances in private subnets
   - ALB handles HTTPS termination
   - Security groups restrict access

3. **Deployment Security**:
   - SSM requires IAM permissions
   - No SSH keys on instances
   - Audit trail in CloudTrail

## Testing Deployment

### Manual Test
```bash
# Set GitHub PAT
export GITHUB_PAT="your-token"

# Test deployment
./deploy.sh deploy

# Check workflow
# Visit: https://github.com/youwoai/humansa-ml-server/actions

# Verify health
curl -I https://humansa.youwo.ai/health
```

### Automated Verification
The deployment workflow includes:
- Automatic health checks after deployment
- Slack notifications on completion
- CloudWatch alarms for failures

## Conclusion

The Humansa deployment system follows the exact same patterns as YouWoAI:
- GitHub Actions for CI/CD
- AWS SSM for secure deployment
- Docker containers for consistency
- ALB health checks for verification
- Zero-downtime deployments

The main simplification is removing components Humansa doesn't need (S3, multiple services) while maintaining the same deployment reliability and security.