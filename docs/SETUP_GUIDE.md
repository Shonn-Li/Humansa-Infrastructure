# Humansa Infrastructure Setup Guide

## Quick Start

### 1. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit with your values:
```hcl
# Database (you choose these)
db_username = "humansa_admin"
db_password = "StrongPassword123!"  # Make it strong!

# Your AWS Route53 zone
route53_zone_id = "Z1234567890ABC"  # From Route53 console

# API Authentication tokens (generate these)
api_tokens = [
  "first-token-here",
  "second-token-here",
  "third-token-here"
]

# For deployments (optional for now)
github_pat = "ghp_xxxx"  # Can use dummy value initially

# SSH key (generate: ssh-keygen -t rsa -b 4096)
ssh_public_key = "ssh-rsa AAAAB3..."

# Monitoring
alarm_email = "your-email@example.com"
```

### 2. Deploy Infrastructure

```bash
# Review what will be created
./terraform-plan.sh

# Apply if it looks good
./terraform-apply.sh tfplan-TIMESTAMP
```

### 3. What Gets Created

1. **Empty PostgreSQL Database**
   - Database name: "humansa"
   - Master user: your db_username
   - Password: your db_password
   - Stored in SSM: `/humansa/production/db_*`

2. **ML Server Instances**
   - Auto-scaling group (2 instances)
   - Public IPs (no NAT gateway needed)
   - IAM role to read SSM parameters

3. **Load Balancer**
   - HTTPS endpoint at humansa.youwo.ai
   - Health checks on /health

4. **Redis Cache**
   - Single node (no password by default)

### 4. Database Initialization

**Important**: Terraform only creates an EMPTY database. Your application must:

1. **Connect using SSM parameters**:
   ```python
   # Your ML app should read from SSM
   db_host = get_ssm_parameter('/humansa/production/db_host')
   db_pass = get_ssm_parameter('/humansa/production/db_password')
   ```

2. **Create schema on first run**:
   - Use migrations (Alembic for Python)
   - Or create tables in application startup
   - Or run SQL scripts manually

### 5. Manual Secret Setup (After Infrastructure)

Run the setup script for API keys:
```bash
./setup-secrets.sh
```

This will prompt for:
- OpenAI API key (required)
- Other LLM keys (optional)
- Auto-generates JWT secrets

### 6. Cost Breakdown

**Daily**: ~$10.73/day
**Monthly**: ~$322/month

**With optimizations**: ~$5.97/day ($179/month)

### 7. Key Differences from YouWoAI

| Feature | YouWoAI | Humansa |
|---------|---------|---------|
| Database name | "active" | "humansa" |
| GitHub PAT | Required for ghcr.io | Optional |
| Redis password | Required | Optional |
| Schema setup | TypeORM migrations | Your choice |
| Container registry | ghcr.io | Docker Hub/ECR |

### 8. Testing Your Deployment

```bash
# Check if infrastructure is up
curl -I https://humansa.youwo.ai/health

# View outputs
terraform output -json

# Check SSM parameters
aws ssm get-parameter --name "/humansa/production/db_host"
```

### 9. Destroy When Done Testing

```bash
./terraform-destroy.sh
```

## Common Issues

**Q: Do I need the GitHub PAT?**
A: Not immediately. It's used for automated deployments. You can add it later.

**Q: How do I initialize the database schema?**
A: Your ML application should handle this. Common patterns:
- SQLAlchemy/Alembic migrations (Python)
- Prisma migrations (Node.js)
- Raw SQL scripts on startup

**Q: Why no NAT Gateway?**
A: Following YouWoAI pattern - instances in public subnets with security groups. Saves $85/month.

**Q: Can I use a smaller database?**
A: Yes! Change to db.t3.small in database.tf to save $43/month.