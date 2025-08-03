# Humansa Secrets Documentation

## Overview

Humansa uses AWS Systems Manager Parameter Store for all secrets management. Secrets are divided into two categories:

1. **Terraform-managed** - Created automatically during infrastructure deployment
2. **Manually-managed** - Must be set up using `setup-secrets.sh` script

## Terraform-Managed Parameters

These are created automatically when you run `terraform apply`:

### Database Parameters
- `/humansa/production/db_host` - RDS endpoint hostname
- `/humansa/production/db_port` - Database port (5432)
- `/humansa/production/db_username` - Master username
- `/humansa/production/db_password` - Master password (SecureString)
- `/humansa/production/db_name` - Database name
- `/humansa/production/db/connection_string` - Full connection string (SecureString)

### Redis Parameters
- `/humansa/production/redis_host` - ElastiCache endpoint
- `/humansa/production/redis_port` - Redis port (6379)
- `/humansa/production/redis/endpoint` - Full endpoint
- `/humansa/production/redis/auth_token` - Redis auth token (SecureString)

### API Authentication
- `/humansa/production/api/token_0` - API token 1 (SecureString)
- `/humansa/production/api/token_1` - API token 2 (SecureString)
- `/humansa/production/api/token_2` - API token 3 (SecureString)

### Infrastructure References
- `/humansa/production/alb_dns_name` - Load balancer DNS
- `/humansa/production/target_group_arn` - ALB target group
- `/humansa/production/asg_name` - Auto Scaling Group name
- `/humansa/production/image_tag` - Current Docker image tag

### GitHub
- `/humansa/production/github/pat` - GitHub Personal Access Token (SecureString)

## Manually-Managed Secrets

Run `./setup-secrets.sh` to set up these secrets:

### LLM API Keys (Required)
- `/humansa/production/api/openai_key` - OpenAI API key (required)
- `/humansa/production/api/anthropic_key` - Anthropic/Claude key (optional)
- `/humansa/production/api/deepseek_key` - DeepSeek API key (optional)
- `/humansa/production/api/gemini_key` - Google Gemini key (optional)

### Authentication Secrets (Auto-generated)
- `/humansa/production/auth/jwt_secret` - JWT signing secret
- `/humansa/production/auth/session_secret` - Session encryption

### Monitoring (Optional)
- `/humansa/production/monitoring/sentry_dsn` - Sentry error tracking
- `/humansa/production/notifications/slack_webhook` - Slack notifications

### Configuration
- `/humansa/production/config/environment` - Environment name
- `/humansa/production/config/region` - AWS region
- `/humansa/production/config/log_level` - Log level (INFO/DEBUG)

## Application Usage

The ML server should read these parameters at startup:

```python
import boto3

ssm = boto3.client('ssm', region_name='ap-east-1')

def get_parameter(name, decrypt=True):
    response = ssm.get_parameter(
        Name=f'/humansa/production/{name}',
        WithDecryption=decrypt
    )
    return response['Parameter']['Value']

# Database connection
db_config = {
    'host': get_parameter('db_host', decrypt=False),
    'port': get_parameter('db_port', decrypt=False),
    'database': get_parameter('db_name', decrypt=False),
    'user': get_parameter('db_username', decrypt=False),
    'password': get_parameter('db_password', decrypt=True)
}

# Or use the connection string directly
db_url = get_parameter('db/connection_string', decrypt=True)

# API keys
openai_key = get_parameter('api/openai_key', decrypt=True)

# API authentication tokens
api_tokens = []
for i in range(3):
    token = get_parameter(f'api/token_{i}', decrypt=True)
    api_tokens.append(token)
```

## Security Best Practices

1. **Least Privilege**: EC2 instances only have access to `/humansa/production/*` parameters
2. **Encryption**: All sensitive values use SecureString type
3. **Rotation**: Rotate API tokens and secrets regularly
4. **Audit**: Enable CloudTrail to track parameter access
5. **No Hardcoding**: Never hardcode secrets in code or environment variables

## Comparison with YouWoAI

YouWoAI stores similar parameters but includes:
- S3 bucket names (not needed for Humansa)
- Separate app/ML server parameters (Humansa is single service)
- No API authentication tokens (uses different auth method)

## Troubleshooting

### List all parameters
```bash
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Values=/humansa/production" \
  --region ap-east-1
```

### Get a specific parameter
```bash
aws ssm get-parameter \
  --name "/humansa/production/api/openai_key" \
  --with-decryption \
  --region ap-east-1
```

### Check IAM permissions
```bash
aws ssm get-parameter \
  --name "/humansa/production/db_host" \
  --region ap-east-1
```

If this fails, check the instance's IAM role has the correct policy attached.