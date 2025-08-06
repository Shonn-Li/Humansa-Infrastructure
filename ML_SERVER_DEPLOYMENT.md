# Humansa ML Server Deployment Documentation

## Overview

This document outlines the complete deployment process for the Humansa ML Server, including:
- Required credentials and secrets
- GitHub Container Registry (GHCR) setup
- EC2 user data script configuration
- Deployment workflow
- Environment variables and SSM parameters

## Architecture Overview

```
GitHub Repository → GitHub Actions → GHCR → EC2 Instances → RDS
                                             ↓
                                           ALB → Users
```

## 1. Required Credentials and Secrets

### 1.1 GitHub Secrets Required

Add these to your Humansa ML Server GitHub repository under Settings → Secrets:

#### AWS Deployment Credentials (REQUIRED)
```yaml
# For GitHub Actions to deploy to EC2
AWS_DEPLOY_ACCESS_KEY: [IAM user access key with EC2/SSM permissions]
AWS_DEPLOY_SECRET_ACCESS_KEY: [IAM user secret key]
AWS_REGION: ap-east-1
SSH_PRIVATE_KEY: [Your private key content for EC2 SSH access]

# OR use OIDC (recommended)
AWS_ROLE: arn:aws:iam::992382528744:role/humansa-github-actions-role
AWS_REGION: ap-east-1
```

#### Container Registry (REQUIRED)
```yaml
GHCR_PAT: [GitHub Personal Access Token with packages:write permission]
# Note: Can also use GITHUB_TOKEN if repo permissions are set correctly
```

#### API Keys for Runtime (passed to Ansible)

**REQUIRED API Keys:**
```yaml
# Core LLM Providers (at least one required)
OPENAI_API_KEY: sk-...              # OpenAI models and embeddings
ANTHROPIC_API_KEY: sk-ant-...       # Claude models

# AWS Runtime Access
AWS_ACCESS_KEY: AKIA...             # For S3, CloudWatch, etc.
AWS_SECRET_ACCESS_KEY: ...          # AWS secret key
```

**OPTIONAL API Keys (for additional providers):**
```yaml
# Additional LLM Providers
DEEPSEEK_API_KEY: ...               # DeepSeek models (R1, V3)
GOOGLE_API_KEY: ...                 # Gemini models
XAI_API_KEY: ...                    # X.AI Grok models
AZURE_INFERENCE_ENDPOINT: ...       # Azure AI Inference endpoint URL
AZURE_INFERENCE_CREDENTIAL: ...     # Azure AI Inference API key

# Web Scraping Proxy (for link analysis)
WEBSHARE_PROXY_USERNAME: ...        # Webshare proxy username
WEBSHARE_PROXY_PASSWORD: ...        # Webshare proxy password

# Memory Layer
MEM0_API_KEY: ...                   # Mem0 cloud API (if using cloud version)
```

### 1.2 SSM Parameters Structure

The deployment uses two approaches for configuration:

#### Parameters Created Automatically by Terraform

These are created by your infrastructure deployment and stored under `/humansa/production/`:

```yaml
# Infrastructure outputs (created by Terraform)
/humansa/production/alb_dns_name       # ALB DNS name
/humansa/production/asg_name           # Auto-scaling group name  
/humansa/production/ml_tg_arn          # Target group ARN (for Ansible)
/humansa/production/vpc_id             # VPC ID
/humansa/production/db_host            # RDS endpoint
/humansa/production/db_port            # Database port (5432)
/humansa/production/db_username        # Database username
/humansa/production/db_password        # Database password (SecureString)
/humansa/production/db_name            # Database name (humansa)
```

#### Parameters Fetched by Ansible Playbook

The Ansible playbook fetches ALL parameters under `/humansa/production/` recursively and converts them to environment variables. For example:

```yaml
# If you have these in SSM:
/humansa/production/db_host           → DB_HOST
/humansa/production/db_port           → DB_PORT
/humansa/production/db_username       → DB_USERNAME
/humansa/production/db_password       → DB_PASSWORD (SecureString)
/humansa/production/ml_server_url     → ML_SERVER_URL
/humansa/production/github_pat        → GITHUB_PAT (SecureString)
```

**Important**: The playbook automatically:
1. Fetches all parameters under `/humansa/production/`
2. Takes the last part of the path and converts to uppercase
3. Creates environment variables from them

#### Manual SSM Parameters to Create (Optional)

If you want to store configuration in SSM instead of passing via GitHub Secrets:

```bash
# Database configuration (if not using GitHub Secrets)
aws ssm put-parameter \
  --name "/humansa/production/db_host" \
  --value "YOUR_RDS_ENDPOINT" \
  --type "String" \
  --region ap-east-1

aws ssm put-parameter \
  --name "/humansa/production/db_password" \
  --value "YOUR_DB_PASSWORD" \
  --type "SecureString" \
  --region ap-east-1

# ML Server version tracking
aws ssm put-parameter \
  --name "/humansa/production/ml_server_image_tag" \
  --value "latest" \
  --type "String" \
  --region ap-east-1

# GitHub PAT for user data script
aws ssm put-parameter \
  --name "/humansa/production/github_pat" \
  --value "YOUR_GITHUB_PAT" \
  --type "SecureString" \
  --region ap-east-1
```

## 2. API Key Requirements Summary

### Minimum Required for Basic Operation:
- **OPENAI_API_KEY** OR **ANTHROPIC_API_KEY** (at least one LLM provider)
- **AWS_ACCESS_KEY** and **AWS_SECRET_ACCESS_KEY** (for AWS services)
- **AWS_DEPLOY_ACCESS_KEY** and **AWS_DEPLOY_SECRET_ACCESS_KEY** (for deployment)
- **GHCR_PAT** (for container registry access)
- **SSH_PRIVATE_KEY** (for EC2 access)

### Recommended for Full Functionality:
- **OPENAI_API_KEY** (for embeddings and GPT models)
- **ANTHROPIC_API_KEY** (for Claude models)
- **DEEPSEEK_API_KEY** (for cost-effective inference)
- **AZURE_INFERENCE_ENDPOINT** and **AZURE_INFERENCE_CREDENTIAL** (for Azure models)

## 3. GitHub Container Registry (GHCR) Setup

### 2.1 Create GitHub Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Create a new token with these permissions:
   - `write:packages` - Upload packages to GitHub Package Registry
   - `read:packages` - Download packages from GitHub Package Registry
   - `delete:packages` - (optional) Delete packages from GitHub Package Registry

3. Save this token as `GHCR_PAT` in GitHub Secrets

### 2.2 Container Repository

Your Docker images will be stored at:
```
ghcr.io/[your-github-username]/humansa-ml-server:VERSION
```

Example:
```
ghcr.io/shonn-li/humansa-ml-server:1.0.0
```

## 4. Deployment Scripts

### 3.1 Enhanced User Data Script

Update the user data script in `modules/compute/user_data.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Log all output
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "Starting Humansa ML Server setup at $(date)"

# Update system
yum update -y

# Install required packages
yum install -y \
    docker \
    git \
    python3 \
    python3-pip \
    amazon-cloudwatch-agent \
    aws-cli \
    jq

# Start Docker
systemctl enable docker
systemctl start docker

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

# Configure AWS CLI
aws configure set default.region $REGION

# Get credentials from SSM Parameter Store
echo "Fetching configuration from SSM..."
GITHUB_PAT=$(aws ssm get-parameter \
    --name "/${project_name}/${environment}/github/pat" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text)

DB_HOST=$(aws ssm get-parameter \
    --name "/${project_name}/${environment}/db/host" \
    --query 'Parameter.Value' \
    --output text)

DB_PASSWORD=$(aws ssm get-parameter \
    --name "/${project_name}/${environment}/db/password" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text)

IMAGE_TAG=$(aws ssm get-parameter \
    --name "/${project_name}/${environment}/ml_server_image_tag" \
    --query 'Parameter.Value' \
    --output text)

# Login to GitHub Container Registry
echo "Logging into GitHub Container Registry..."
echo $GITHUB_PAT | docker login ghcr.io -u ${github_username} --password-stdin

# Create directories
mkdir -p /var/log/humansa-ml
mkdir -p /opt/humansa

# Create environment file for ML server
cat > /opt/humansa/.env <<EOF
# Database Configuration
DB_HOST=$DB_HOST
DB_PORT=5432
DB_USERNAME=${db_username}
DB_PASSWORD=$DB_PASSWORD
DB_ACTIVE_DATABASE=${db_name}

# Server Configuration
ML_SERVER_PORT=5001
ENVIRONMENT=${environment}
PROJECT_NAME=${project_name}
INSTANCE_ID=$INSTANCE_ID

# AWS Configuration
AWS_REGION=$REGION

# API Keys (loaded from SSM in production)
# These will be passed via docker run -e flags
EOF

# Pull and run the ML server container
echo "Pulling ML server image..."
docker pull ghcr.io/${github_repo}:$IMAGE_TAG

echo "Starting ML server container..."
docker run -d \
    --name humansa-ml \
    --restart unless-stopped \
    -p 5001:5001 \
    -v /var/log/humansa-ml:/app/logs \
    -v /opt/humansa/.env:/app/.env:ro \
    --env-file /opt/humansa/.env \
    ghcr.io/${github_repo}:$IMAGE_TAG

# Setup health check script
cat > /usr/local/bin/health-check.sh <<'SCRIPT'
#!/bin/bash
if curl -f http://localhost:5001/health > /dev/null 2>&1; then
    exit 0
else
    echo "Health check failed at $(date), restarting container..."
    docker restart humansa-ml
    sleep 30
    if curl -f http://localhost:5001/health > /dev/null 2>&1; then
        echo "Container recovered after restart"
        exit 0
    else
        echo "Container still unhealthy after restart"
        exit 1
    fi
fi
SCRIPT
chmod +x /usr/local/bin/health-check.sh

# Add cron job for health check every 5 minutes
echo "*/5 * * * * /usr/local/bin/health-check.sh >> /var/log/health-check.log 2>&1" | crontab -

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "metrics": {
    "namespace": "${project_name}-${environment}",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/humansa-ml/*.log",
            "log_group_name": "/aws/ec2/humansa-ml/${environment}",
            "log_stream_name": "{instance_id}/{ip_address}",
            "retention_in_days": 30
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/humansa-ml/${environment}/setup",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a query -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Signal completion
aws ssm put-parameter \
    --name "/${project_name}/${environment}/instance/$INSTANCE_ID/status" \
    --value "ready" \
    --type String \
    --overwrite || true

echo "Humansa ML Server setup completed at $(date)"
```

### 3.2 GitHub Actions Workflow

Create `.github/workflows/release.yml` in your Humansa ML Server repository:

```yaml
name: Build and Deploy Humansa ML Server

on:
  push:
    tags:
      - "release-*"

permissions:
  id-token: write
  contents: read
  packages: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.get_version.outputs.version }}
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GHCR_PAT || secrets.GITHUB_TOKEN }}

      - name: Extract version number
        id: get_version
        run: |
          echo "version=$(echo ${{ github.ref }} | sed -e 's|refs/tags/release-||')" >> $GITHUB_ENV
          echo "version=$(echo ${{ github.ref }} | sed -e 's|refs/tags/release-||')" >> $GITHUB_OUTPUT

      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          platforms: linux/amd64,linux/arm64
          tags: ghcr.io/${{ github.repository_owner }}/humansa-ml-server:${{ env.version }}

      - name: Pull the Docker image to verify permissions
        run: |
          docker pull ghcr.io/${{ github.repository_owner }}/humansa-ml-server:${{ env.version }}
          docker images

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.x"

      - name: Install Ansible and AWS CLI dependencies
        run: |
          python -m pip install --upgrade pip
          pip install ansible boto3
          ansible-galaxy collection install community.aws --force
          ansible-galaxy collection install amazon.aws --force
          ansible-galaxy collection install community.docker --force

      - name: Configure AWS CLI
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_DEPLOY_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.AWS_DEPLOY_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Set up AWS credentials for Ansible
        run: |
          mkdir -p ~/.aws
          cat > ~/.aws/credentials << EOF
          [default]
          aws_access_key_id = ${{ secrets.AWS_DEPLOY_ACCESS_KEY }}
          aws_secret_access_key = ${{ secrets.AWS_DEPLOY_SECRET_ACCESS_KEY }}
          EOF
          cat > ~/.aws/config << EOF
          [default]
          region = ${{ secrets.AWS_REGION }}
          EOF

      - name: Set Up SSH Key
        run: |
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > deploy_key.pem
          chmod 600 deploy_key.pem

      - name: Extract version number
        id: get_version
        run: echo "version=${{ needs.build-and-push.outputs.version }}" >> $GITHUB_ENV

      - name: Persist tag to SSM
        run: |
          aws ssm put-parameter \
            --name /humansa/production/ml_server_image_tag \
            --type String --overwrite \
            --value "${{ env.version }}"

      - name: Debug inventory
        run: |
          echo "Testing AWS EC2 inventory..."
          ansible-inventory -i inventory_aws_ec2.yml --list
          echo ""
          echo "Available hosts:"
          ansible-inventory -i inventory_aws_ec2.yml --graph

      - name: Run Ansible Playbook
        run: |
          ansible-playbook -i inventory_aws_ec2.yml ml-playbook.yml --extra-vars "
            aws_deploy_access_key=${{ secrets.AWS_DEPLOY_ACCESS_KEY }}
            aws_deploy_secret_access_key=${{ secrets.AWS_DEPLOY_SECRET_ACCESS_KEY }}
            ansible_ssh_private_key_file=deploy_key.pem 
            ansible_user=ec2-user 
            ghcr_username=${{ github.actor }}
            ghcr_token=${{ secrets.GITHUB_TOKEN }}
            ghcr_repository=${{ github.repository_owner }}/humansa-ml-server
            image_tag=${{ env.version }}
            aws_region=${{ secrets.AWS_REGION }}
            openai_api_key=${{ secrets.OPENAI_API_KEY }}
            aws_access_key=${{ secrets.AWS_ACCESS_KEY }}
            aws_secret_access_key=${{ secrets.AWS_SECRET_ACCESS_KEY }}
            anthropic_api_key=${{ secrets.ANTHROPIC_API_KEY }}
            deepseek_api_key=${{ secrets.DEEPSEEK_API_KEY }}
            google_api_key=${{ secrets.GOOGLE_API_KEY }}
            xai_api_key=${{ secrets.XAI_API_KEY }}
            azure_inference_endpoint=${{ secrets.AZURE_INFERENCE_ENDPOINT }}
            azure_inference_credential=${{ secrets.AZURE_INFERENCE_CREDENTIAL }}
            webshare_proxy_username=${{ secrets.WEBSHARE_PROXY_USERNAME }}
            webshare_proxy_password=${{ secrets.WEBSHARE_PROXY_PASSWORD }}" || [ $? -eq 2 ]
```

### 3.3 Dockerfile for Humansa ML Server

Create a `Dockerfile` in your ML server repository:

```dockerfile
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY run.sh .
RUN chmod +x run.sh

# Create directories
RUN mkdir -p /app/logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5001/health || exit 1

# Expose port
EXPOSE 5001

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV ML_SERVER_PORT=5001

# Run the application
CMD ["./run.sh"]
```

### 3.4 run.sh script

Create `run.sh` in your ML server repository:

```bash
#!/bin/bash
set -e

echo "Starting Humansa ML Server..."
echo "Environment: ${ENVIRONMENT:-development}"
echo "Port: ${ML_SERVER_PORT:-5001}"

# Start the server
exec python src/main.py
```

## 5. Manual Deployment Steps

### 4.1 Initial Setup

1. **Create GitHub PAT**:
   ```bash
   # Go to GitHub → Settings → Developer settings → Personal access tokens
   # Create token with write:packages permission
   # Save as GHCR_PAT in GitHub Secrets
   ```

2. **Store PAT in SSM**:
   ```bash
   aws ssm put-parameter \
     --name "/humansa/production/github/pat" \
     --value "YOUR_GITHUB_PAT" \
     --type "SecureString" \
     --region ap-east-1
   ```

3. **Update user data variables**:
   - Set `github_username` in Terraform variables
   - Set `github_repo` to your GHCR repository path

### 4.2 Deployment Workflow

1. **Tag your release**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **GitHub Actions will**:
   - Build Docker image
   - Push to GHCR
   - Update SSM parameter with new tag
   - Trigger EC2 instance refresh

3. **EC2 instances will**:
   - Pull new image from GHCR
   - Restart container with new version
   - Report health status

## 6. Environment Variables for ML Server

### Database Configuration
The ML server will receive these from SSM parameters:

Your ML server should support these environment variables:

```python
# Database
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = int(os.getenv('DB_PORT', 5432))
DB_USERNAME = os.getenv('DB_USERNAME', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_ACTIVE_DATABASE = os.getenv('DB_ACTIVE_DATABASE', 'humansa')

# Server
ML_SERVER_PORT = int(os.getenv('ML_SERVER_PORT', 6001))  # Humansa uses port 6001
ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
DB_ACTIVE_DATABASE = os.getenv('DB_ACTIVE_DATABASE', 'humansa')

# API Keys
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY')
# ... other API keys

# AWS
AWS_REGION = os.getenv('AWS_REGION', 'ap-east-1')
```

## 7. Monitoring and Logs

### 6.1 CloudWatch Logs

Logs are available in CloudWatch under:
- `/aws/ec2/humansa-ml/production` - Application logs
- `/aws/ec2/humansa-ml/production/setup` - Setup logs

### 6.2 Health Checks

- **Container health**: `http://localhost:5001/health`
- **ALB health**: Checks `/health` endpoint
- **Auto-recovery**: Cron job restarts unhealthy containers

### 6.3 Metrics

CloudWatch metrics available:
- CPU utilization
- Memory usage
- Disk usage
- Custom application metrics

## 8. Troubleshooting

### 7.1 Container won't start

1. Check CloudWatch logs for errors
2. SSH to instance and check:
   ```bash
   docker logs humansa-ml
   docker ps -a
   cat /var/log/user-data.log
   ```

### 7.2 GHCR authentication fails

1. Verify PAT has correct permissions
2. Check PAT in SSM:
   ```bash
   aws ssm get-parameter \
     --name "/humansa/production/github/pat" \
     --with-decryption
   ```

### 7.3 Database connection fails

1. Verify RDS endpoint in SSM
2. Check security group allows connection
3. Verify database credentials

## 9. Cost Optimization

- Use instance refresh instead of replacing all instances
- Configure auto-scaling based on actual load
- Use spot instances for non-critical workloads
- Monitor CloudWatch costs

## 10. Security Best Practices

1. **Never commit secrets** - Use SSM Parameter Store
2. **Rotate credentials regularly**
3. **Use IAM roles** instead of access keys where possible
4. **Enable CloudTrail** for audit logging
5. **Restrict GHCR access** to specific repositories
6. **Use VPC endpoints** for AWS services