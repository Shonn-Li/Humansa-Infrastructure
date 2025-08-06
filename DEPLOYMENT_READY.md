# Humansa ML Server - Deployment Ready

## Current Status
✅ Infrastructure deployed and cost-optimized
✅ Load balancer active at https://humansa.youwo.ai (502 - awaiting ML server)
✅ Release workflow configured
✅ Playbook updated with all API keys
✅ Testing scripts created
✅ Documentation complete

## Required GitHub Secrets

Before deployment, ensure these secrets are set in GitHub repository settings:

### Critical API Keys (MUST HAVE)
- [ ] `OPENAI_API_KEY` - For GPT models
- [ ] `ANTHROPIC_API_KEY` - For Claude models
- [ ] `AWS_ACCESS_KEY` - For AWS services (S3, etc.)
- [ ] `AWS_SECRET_ACCESS_KEY` - AWS secret key
- [ ] `AWS_REGION` - Set to: us-west-1
- [ ] `GHCR_PAT` - GitHub token with packages:write permission
- [ ] `SSH_PRIVATE_KEY` - SSH key for EC2 access

### Optional API Keys (Nice to Have)
- [ ] `DEEPSEEK_API_KEY` - DeepSeek models
- [ ] `GOOGLE_API_KEY` - Gemini models
- [ ] `XAI_API_KEY` - Grok models
- [ ] `AZURE_INFERENCE_ENDPOINT` - Azure OpenAI endpoint
- [ ] `AZURE_INFERENCE_CREDENTIAL` - Azure credential
- [ ] `SERPER_API_KEY` - Web search
- [ ] `SPIDER_API_KEY` - Web scraping
- [ ] `MEM0_API_KEY` - Memory service
- [ ] `WEBSHARE_PROXY_USERNAME` - Proxy username
- [ ] `WEBSHARE_PROXY_PASSWORD` - Proxy password
- [ ] `OPENAI_ASSISTANT_3_ID` - GPT-3.5 assistant
- [ ] `OPENAI_ASSISTANT_4_ID` - GPT-4 assistant

## Deployment Steps

### 1. Setup SSM Parameters
```bash
cd /Users/shonnli/Non-icloudFile/YouWoAI/Code_V1/humansa-infrastructure
./scripts/setup_ssm_parameters.sh
```

### 2. Prepare ML Server Code
```bash
# Copy the ML server code to a deployment repository
cp -r /Users/shonnli/Non-icloudFile/YouWoAI/Code_Copy/Copy-1/humansa-ml-server /tmp/
cd /tmp/humansa-ml-server

# Initialize git repository
git init
git add .
git commit -m "Initial Humansa ML Server code"

# Push to GitHub (create repo first on GitHub)
git remote add origin https://github.com/[YOUR-ORG]/humansa-ml-server.git
git push -u origin main
```

### 3. Trigger Deployment
```bash
# In the infrastructure repository
cd /Users/shonnli/Non-icloudFile/YouWoAI/Code_V1/humansa-infrastructure

# Create and push release tag
git add .
git commit -m "feat: complete Humansa ML deployment configuration"
git tag release-1.0.0
git push origin release-1.0.0
```

### 4. Monitor Deployment
Watch the GitHub Actions workflow:
- Go to: https://github.com/Shonn-Li/Humansa-Infrastructure/actions
- Monitor the "Build and Deploy Humansa ML Server" workflow
- Check both build and deploy jobs complete successfully

### 5. Test Deployment
```bash
# Quick test
./scripts/quick_test.sh

# Comprehensive test
python3 scripts/test_humansa_endpoints.py
```

## Files Created/Updated

### Updated Files
- `.github/workflows/release.yml` - Added missing API keys
- `ml-playbook.yml` - Added search APIs and assistant IDs

### New Files Created
- `HUMANSA_ML_DEPLOYMENT_GUIDE.md` - Complete deployment documentation
- `scripts/setup_ssm_parameters.sh` - SSM parameter setup script
- `scripts/test_humansa_endpoints.py` - Comprehensive endpoint testing
- `scripts/quick_test.sh` - Quick connectivity test
- `DEPLOYMENT_READY.md` - This checklist

## Architecture Summary

### Port Configuration
- ML Server Port: 6001
- Database: PostgreSQL on RDS
- Load Balancer: https://humansa.youwo.ai

### Environment Settings
- `DIGIT=1` - Instance identifier
- `ENVIRONMENT=production`
- `DB_ACTIVE_DATABASE=humansa`
- `HUMANSA_USE_SUBAGENT_ARCHITECTURE=true`
- `HUMANSA_ENHANCED_LOGGING=true`

### Infrastructure (Cost-Optimized)
- EC2 Instances: 2x t3.micro (1GB RAM each)
- Auto Scaling: Min=2, Max=3
- RDS: db.t3.micro
- Monthly Cost: ~$40-45

## Endpoints Available After Deployment

### Core Endpoints
- `GET /health` - Health check
- `GET /ping` - Basic connectivity
- `POST /v1/chat/completions` - Chat with streaming support
- `POST /v1/multi-agent/response` - Multi-agent workflows

### Humansa V2 Medical
- `POST /v2/humansa/chat` - Medical consultation
- `POST /v2/humansa/appointment/search` - Search appointments
- `POST /v2/humansa/appointment/book` - Book appointments

### Memory Service
- `GET /v2/humansa/memory/status` - Check service status
- `POST /v2/humansa/memory/add` - Add to memory
- `GET /v2/humansa/memory/context/{user_id}` - Get user context

## Troubleshooting

### If deployment fails:
1. Check GitHub Actions logs for errors
2. Verify all required secrets are set
3. Check AWS CloudWatch logs: `/aws/ec2/humansa-ml-server`
4. SSH to instance and check Docker: `docker logs humansa-ml`

### If endpoints return errors:
1. Check API keys are valid and not expired
2. Verify database connectivity
3. Check security groups allow traffic
4. Review application logs for specific errors

## Next Actions Required

1. **Set GitHub Secrets** - Add all required API keys to repository
2. **Setup SSM Parameters** - Run the setup script
3. **Deploy ML Server Code** - Push code to GitHub repository
4. **Trigger Deployment** - Create release tag
5. **Test Endpoints** - Verify all endpoints work correctly

---
**Status**: Ready for deployment once GitHub secrets are configured