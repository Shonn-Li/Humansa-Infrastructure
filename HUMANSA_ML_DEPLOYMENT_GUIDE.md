# Humansa ML Server Deployment Guide

## Overview
This guide documents the complete deployment process for the Humansa ML Server, including all required API keys, SSM parameters, and testing procedures.

## Required GitHub Secrets

You must configure the following secrets in your GitHub repository settings:

### Core LLM Provider API Keys
- `OPENAI_API_KEY` - OpenAI API key for GPT models
- `ANTHROPIC_API_KEY` - Anthropic API key for Claude models
- `DEEPSEEK_API_KEY` - DeepSeek API key
- `GOOGLE_API_KEY` - Google API key for Gemini models
- `XAI_API_KEY` - X.AI API key for Grok models

### Azure OpenAI
- `AZURE_INFERENCE_ENDPOINT` - Azure OpenAI endpoint URL
- `AZURE_INFERENCE_CREDENTIAL` - Azure OpenAI credential key

### Web Search APIs
- `SERPER_API_KEY` - Serper.dev API key for web search
- `SPIDER_API_KEY` - Spider API key for web scraping

### OpenAI Assistants
- `OPENAI_ASSISTANT_3_ID` - OpenAI Assistant ID for GPT-3.5
- `OPENAI_ASSISTANT_4_ID` - OpenAI Assistant ID for GPT-4

### Memory Service
- `MEM0_API_KEY` - Mem0 API key for conversation memory

### Proxy Configuration
- `WEBSHARE_PROXY_USERNAME` - Webshare proxy username
- `WEBSHARE_PROXY_PASSWORD` - Webshare proxy password

### AWS Deployment Credentials
- `AWS_DEPLOY_ACCESS_KEY` - AWS IAM access key for deployment
- `AWS_DEPLOY_SECRET_ACCESS_KEY` - AWS IAM secret key for deployment
- `AWS_ACCESS_KEY` - AWS access key for S3/other services
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for S3/other services
- `AWS_REGION` - AWS region (e.g., us-west-1)

### GitHub Container Registry
- `GHCR_PAT` - GitHub Personal Access Token with packages:write permission

### SSH Deployment
- `SSH_PRIVATE_KEY` - Private SSH key for EC2 instance access

## SSM Parameters Configuration

The following parameters are automatically pulled from AWS SSM Parameter Store:

```bash
# Database configuration (from terraform outputs)
/humansa/production/db_host
/humansa/production/db_port
/humansa/production/db_user
/humansa/production/db_password
/humansa/production/db_name

# Infrastructure references
/humansa/production/ml_tg_arn
/humansa/production/ml_server_image_tag
```

## Deployment Process

### 1. Initial Setup

```bash
# Clone the infrastructure repository
git clone https://github.com/Shonn-Li/Humansa-Infrastructure.git
cd humansa-infrastructure

# Configure all GitHub secrets listed above
# Go to Settings > Secrets and variables > Actions
```

### 2. Build and Deploy

```bash
# Create a release tag to trigger deployment
git tag release-1.0.0
git push origin release-1.0.0
```

This will:
1. Build Docker image from humansa-ml-server code
2. Push to GitHub Container Registry
3. Deploy to EC2 instances via Ansible
4. Perform rolling updates with zero downtime

### 3. Manual Deployment (Alternative)

```bash
# Build Docker image locally
cd /path/to/humansa-ml-server
docker build -t ghcr.io/shonn-li/humansa-ml-server:latest .

# Push to registry
echo $GHCR_PAT | docker login ghcr.io -u USERNAME --password-stdin
docker push ghcr.io/shonn-li/humansa-ml-server:latest

# Run Ansible playbook
ansible-playbook -i inventory_aws_ec2.yml ml-playbook.yml \
  --extra-vars "@deploy-vars.yml"
```

## Available Endpoints

Once deployed, the following endpoints will be available at `https://humansa.youwo.ai`:

### Core Chat Endpoints
- `POST /v1/chat/completions` - Modular chat with streaming
- `POST /v1/multi-agent/response` - Multi-agent workflow
- `POST /v1-humansa/chat/completions` - AI-Agent chat

### Humansa V2 Medical Endpoints
- `POST /v2/humansa/chat` - Medical consultation chat
- `POST /v2/humansa/appointment/search` - Search appointments
- `POST /v2/humansa/appointment/book` - Book appointments
- `GET /v2/humansa/patient/profile` - Get patient profile
- `GET /v2/humansa/conversation/history` - Conversation history

### Memory Endpoints
- `POST /v2/humansa/memory/add` - Add to memory
- `POST /v2/humansa/memory/search` - Search memories
- `GET /v2/humansa/memory/context/{user_id}` - Get user context
- `GET /v2/humansa/memory/status` - Memory service status
- `DELETE /v2/humansa/memory/clear/{user_id}` - Clear memories

### Utility Endpoints
- `GET /health` - Health check
- `GET /ping` - Basic connectivity test
- `GET /debug/info` - Debug information

## Testing Scripts

### 1. Health Check Test

```bash
#!/bin/bash
# test_health.sh
echo "Testing Humansa ML Server Health..."
curl -X GET https://humansa.youwo.ai/health
```

### 2. Chat Endpoint Test

```python
#!/usr/bin/env python3
# test_chat.py
import requests
import json

url = "https://humansa.youwo.ai/v1/chat/completions"
headers = {"Content-Type": "application/json"}

payload = {
    "messages": [
        {"role": "user", "content": "Hello, how can you help me today?"}
    ],
    "model": "gpt-4.1-nano",
    "stream": False
}

response = requests.post(url, json=payload, headers=headers)
print(json.dumps(response.json(), indent=2))
```

### 3. Multi-Agent Test

```python
#!/usr/bin/env python3
# test_multi_agent.py
import requests
import json

url = "https://humansa.youwo.ai/v1/multi-agent/response"
headers = {"Content-Type": "application/json"}

payload = {
    "user_id": "test-user-001",
    "conversation_id": "test-conv-001",
    "message": "I need help scheduling a medical appointment",
    "agent_type": "medical_assistant"
}

response = requests.post(url, json=payload, headers=headers)
print(json.dumps(response.json(), indent=2))
```

### 4. Streaming Test

```python
#!/usr/bin/env python3
# test_streaming.py
import requests
import json

url = "https://humansa.youwo.ai/v1/chat/completions"
headers = {"Content-Type": "application/json"}

payload = {
    "messages": [
        {"role": "user", "content": "Tell me about preventive healthcare"}
    ],
    "model": "gpt-4.1-nano",
    "stream": True
}

response = requests.post(url, json=payload, headers=headers, stream=True)
for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))
```

### 5. Memory Service Test

```python
#!/usr/bin/env python3
# test_memory.py
import requests
import json

base_url = "https://humansa.youwo.ai"
user_id = "test-user-001"

# Check memory status
status_response = requests.get(f"{base_url}/v2/humansa/memory/status")
print("Memory Status:", status_response.json())

# Add to memory
memory_data = {
    "user_id": user_id,
    "messages": [
        {"role": "user", "content": "I have diabetes"},
        {"role": "assistant", "content": "I'll note that you have diabetes"}
    ],
    "metadata": {"condition": "diabetes", "severity": "moderate"}
}

add_response = requests.post(
    f"{base_url}/v2/humansa/memory/add",
    json=memory_data
)
print("Memory Added:", add_response.json())

# Get user context
context_response = requests.get(f"{base_url}/v2/humansa/memory/context/{user_id}")
print("User Context:", json.dumps(context_response.json(), indent=2))
```

## Monitoring and Logs

### View Container Logs
```bash
# SSH into EC2 instance
ssh -i deploy_key.pem ec2-user@<instance-ip>

# View logs
docker logs humansa-ml -f

# Check container status
docker ps
docker stats humansa-ml
```

### CloudWatch Logs
Logs are automatically sent to CloudWatch under:
- Log Group: `/aws/ec2/humansa-ml-server`
- Log Stream: `{instance-id}`

### ALB Health Checks
Monitor target health in AWS Console:
- EC2 > Target Groups > humansa-production-ml-tg
- Check "Targets" tab for health status

## Troubleshooting

### Common Issues

1. **Container won't start**
   - Check environment variables in `/etc/humansa-ml-server/.env`
   - Verify all API keys are set correctly
   - Check Docker logs: `docker logs humansa-ml`

2. **Health check failing**
   - Verify port 6001 is accessible
   - Check security group rules
   - Test locally: `curl http://localhost:6001/health`

3. **API key errors**
   - Verify all secrets in GitHub Actions
   - Check SSM parameters are accessible
   - Review `.env` file on EC2 instance

4. **Database connection issues**
   - Verify RDS endpoint in SSM parameters
   - Check security group allows connection
   - Test connection: `psql -h <endpoint> -U postgres -d humansa`

## Rollback Procedure

```bash
# Get previous image tag from SSM
aws ssm get-parameter --name /humansa/production/ml_server_image_tag

# Manually deploy previous version
ansible-playbook -i inventory_aws_ec2.yml ml-playbook.yml \
  --extra-vars "image_tag=<previous-tag>"
```

## Security Notes

1. **Never commit API keys** to the repository
2. **Rotate API keys** regularly
3. **Use IAM roles** for AWS services when possible
4. **Enable CloudTrail** for audit logging
5. **Restrict SSH access** to specific IP ranges
6. **Use secrets rotation** for database passwords

## Cost Optimization

Current configuration uses ultra-optimized settings:
- Instance Type: t3.micro (1GB RAM)
- Min Instances: 2 (for zero-downtime)
- Max Instances: 3
- EBS Volume: 20GB per instance
- RDS: db.t3.micro

Estimated monthly cost: ~$40-45

## Support

For issues or questions:
- Create an issue in the GitHub repository
- Check CloudWatch logs for errors
- Review this documentation for common solutions