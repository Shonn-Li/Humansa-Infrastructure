# Humansa ML Server - API Keys Required

## Overview
This document lists all the API keys and credentials required to deploy and run the Humansa ML Server based on the analysis of the actual codebase.

## GitHub Secrets Required for Deployment

### 1. Deployment Credentials (REQUIRED)
```yaml
# AWS IAM credentials for deployment (created earlier)
AWS_DEPLOY_ACCESS_KEY: AKIA6ODU3VTUM4HCBIX4
AWS_DEPLOY_SECRET_ACCESS_KEY: [The secret key you saved]
AWS_REGION: ap-east-1

# SSH key for EC2 instance access
SSH_PRIVATE_KEY: |
  -----BEGIN RSA PRIVATE KEY-----
  [Content of ~/.ssh/humansa-infrastructure]
  -----END RSA PRIVATE KEY-----

# GitHub Container Registry access
GHCR_PAT: ghp_... # Your GitHub PAT with packages:write permission
```

### 2. Core LLM Provider API Keys (At least ONE required)
```yaml
# OpenAI - RECOMMENDED (used for embeddings and GPT models)
OPENAI_API_KEY: sk-...

# Anthropic - RECOMMENDED (for Claude models)
ANTHROPIC_API_KEY: sk-ant-...
```

### 3. AWS Runtime Credentials (REQUIRED)
```yaml
# For ML server to access S3, CloudWatch, etc.
AWS_ACCESS_KEY: AKIA...
AWS_SECRET_ACCESS_KEY: ...
```

### 4. Additional LLM Providers (OPTIONAL but recommended)
```yaml
# DeepSeek - Cost-effective alternative
DEEPSEEK_API_KEY: ...

# Google Gemini models
GOOGLE_API_KEY: ...

# X.AI Grok models
XAI_API_KEY: ...

# Azure AI Inference (for Azure-hosted models)
AZURE_INFERENCE_ENDPOINT: https://...inference.azure.com
AZURE_INFERENCE_CREDENTIAL: ...
```

### 5. Additional Services (OPTIONAL)
```yaml
# Web scraping proxy (for link analysis features)
WEBSHARE_PROXY_USERNAME: ...
WEBSHARE_PROXY_PASSWORD: ...

# Memory layer (if using Mem0 cloud)
MEM0_API_KEY: ...
```

## Minimum Setup for Basic Functionality

To get Humansa ML Server running with basic functionality, you need:

1. **AWS_DEPLOY_ACCESS_KEY** & **AWS_DEPLOY_SECRET_ACCESS_KEY** (already created)
2. **SSH_PRIVATE_KEY** (your humansa-infrastructure private key)
3. **GHCR_PAT** (GitHub PAT)
4. **OPENAI_API_KEY** OR **ANTHROPIC_API_KEY** (at least one)
5. **AWS_ACCESS_KEY** & **AWS_SECRET_ACCESS_KEY** (for runtime)

## Recommended Setup for Production

For a production-ready deployment with full functionality:

1. All minimum setup keys
2. **OPENAI_API_KEY** (for embeddings - highly recommended)
3. **ANTHROPIC_API_KEY** (for Claude models)
4. **DEEPSEEK_API_KEY** (for cost-effective inference)
5. **AZURE_INFERENCE_ENDPOINT** & **AZURE_INFERENCE_CREDENTIAL** (for Azure models)

## Where to Get These Keys

### OpenAI API Key
1. Go to https://platform.openai.com/api-keys
2. Create a new secret key
3. Copy the key starting with `sk-`

### Anthropic API Key
1. Go to https://console.anthropic.com/
2. Navigate to API Keys
3. Create a new key
4. Copy the key starting with `sk-ant-`

### DeepSeek API Key
1. Go to https://platform.deepseek.com/
2. Create an account
3. Generate API key

### Google API Key (for Gemini)
1. Go to https://makersuite.google.com/app/apikey
2. Create a new API key

### X.AI API Key
1. Go to https://x.ai/api
2. Request access
3. Generate API key when approved

### Azure AI Inference
1. Deploy a model in Azure AI Studio
2. Get the endpoint URL and API key from deployment

### AWS Runtime Credentials
You can either:
- Use the same AWS account (create a new IAM user with appropriate permissions)
- Use the EC2 instance role (recommended for production)

### Webshare Proxy
1. Sign up at https://www.webshare.io/
2. Get proxy credentials from dashboard

## Adding Keys to GitHub

1. Go to your Humansa ML Server repository
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each key with the exact name shown above
5. Paste the value and save

## Notes

- The ML server uses a provider selection system that automatically chooses the best available model based on the API keys provided
- If you only provide one LLM API key, all requests will use that provider
- The server supports multimodal inputs but actual vision capabilities depend on the provider and model
- Port 6001 is used for Humansa (vs 5001 for YouWoAI) to avoid conflicts