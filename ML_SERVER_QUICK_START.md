# Humansa ML Server - Quick Start Guide

## Prerequisites

1. **Infrastructure deployed** (completed ✓)
2. **GitHub repository** for your Humansa ML Server
3. **GitHub Personal Access Token** with `write:packages` permission
4. **ML Server code** with Dockerfile

## Step 1: Create GitHub PAT

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Give it a name: "Humansa ML Server GHCR"
4. Select permissions:
   - ✓ `write:packages`
   - ✓ `read:packages`
5. Generate and copy the token

## Step 2: Store Credentials

Run the deployment script:
```bash
cd humansa-infrastructure
./scripts/deploy-ml-server.sh
```

Select options in order:
1. **Option 1**: Store GitHub PAT
2. **Option 2**: Store database credentials
3. **Option 3**: Store API keys (at minimum OpenAI)

## Step 3: Prepare Your ML Server

Your ML server repository should have:

### Dockerfile
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code
COPY src/ ./src/
COPY run.sh .
RUN chmod +x run.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
  CMD curl -f http://localhost:5001/health || exit 1

EXPOSE 5001

CMD ["./run.sh"]
```

### run.sh
```bash
#!/bin/bash
python src/main.py
```

### GitHub Actions workflow (.github/workflows/deploy.yml)
Copy from `ML_SERVER_DEPLOYMENT.md` section 3.2

### Required Environment Variables
Your ML server will receive ALL parameters from `/humansa/production/` as environment variables:
- Database: `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`
- Server: `ML_SERVER_PORT` (default: 5001), `ML_SERVER_URL`
- API Keys: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc. (from GitHub Secrets)
- AWS: `AWS_ACCESS_KEY`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`

The Ansible playbook automatically:
1. Fetches all SSM parameters under `/humansa/production/`
2. Converts parameter names to uppercase environment variables
3. Merges with API keys passed from GitHub Secrets

## Step 4: Deploy

1. **Add GitHub Secrets** to your ML server repo:
   ```
   # AWS Deployment (choose one method)
   AWS_DEPLOY_ACCESS_KEY: [IAM access key]
   AWS_DEPLOY_SECRET_ACCESS_KEY: [IAM secret key]
   AWS_REGION: ap-east-1
   SSH_PRIVATE_KEY: [Content of ~/.ssh/humansa-infrastructure]
   
   # Container Registry
   GHCR_PAT: [Your GitHub PAT from Step 1]
   
   # API Keys (passed to ML server)
   OPENAI_API_KEY: sk-...
   ANTHROPIC_API_KEY: sk-ant-...
   AWS_ACCESS_KEY: [For ML server AWS access]
   AWS_SECRET_ACCESS_KEY: [For ML server AWS access]
   # Add other optional API keys as needed
   ```

2. **Tag and push** your code:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **GitHub Actions** will automatically:
   - Build Docker image
   - Push to GitHub Container Registry
   - Deploy to EC2 instances

## Step 5: Verify Deployment

```bash
# Check deployment status
./scripts/deploy-ml-server.sh
# Select option 5

# View logs
./scripts/deploy-ml-server.sh
# Select option 6
```

## Quick Commands

### Check ML Server Health
```bash
curl https://humansa.youwo.ai/health
```

### View Instances
```bash
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=humansa-production-ml-asg" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table
```

### SSH to Instance
```bash
ssh -i ~/.ssh/humansa-infrastructure ec2-user@[INSTANCE_IP]
```

### Check Container Logs
```bash
# After SSH to instance
docker logs humansa-ml
```

### Restart Container
```bash
# After SSH to instance
docker restart humansa-ml
```

## Troubleshooting

### Container won't start
1. Check logs: `docker logs humansa-ml`
2. Check environment: `docker exec humansa-ml env`
3. Test database connection from container

### GHCR authentication fails
1. Verify PAT has correct permissions
2. Check PAT hasn't expired
3. Verify GitHub username is correct

### Health check fails
1. Ensure `/health` endpoint returns 200 OK
2. Check if port 5001 is exposed in Dockerfile
3. Verify container is listening on 0.0.0.0:5001 not localhost

## Important URLs

- **ML Server**: https://humansa.youwo.ai
- **Health Check**: https://humansa.youwo.ai/health
- **GitHub Container Registry**: ghcr.io/[your-username]/humansa-ml-server
- **CloudWatch Logs**: AWS Console → CloudWatch → Log groups → /aws/ec2/humansa-ml/production

## Cost Summary

- **Infrastructure**: ~$252/month
- **No additional costs** for ML server deployment
- **Data transfer**: Minimal (API calls only)