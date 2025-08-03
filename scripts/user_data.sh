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

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "metrics": {
    "namespace": "${project_name}-${environment}",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/humansa-ml/app.log",
            "log_group_name": "/aws/application/${project_name}-${environment}",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 30
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

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

# Configure AWS CLI
aws configure set default.region $REGION

# Get GitHub PAT from Parameter Store
GITHUB_PAT=$(aws ssm get-parameter \
    --name "/${project_name}/${environment}/github/pat" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text)

# Login to GitHub Container Registry
echo $GITHUB_PAT | docker login ghcr.io -u USERNAME --password-stdin

# Create app directory
mkdir -p /var/log/humansa-ml
mkdir -p /opt/humansa

# Pull and run the ML server container
docker pull ghcr.io/${github_repo}:latest
docker run -d \
    --name humansa-ml \
    --restart unless-stopped \
    -p 5000:5000 \
    -v /var/log/humansa-ml:/app/logs \
    -e AWS_REGION=$REGION \
    -e ENVIRONMENT=${environment} \
    -e PROJECT_NAME=${project_name} \
    -e INSTANCE_ID=$INSTANCE_ID \
    ghcr.io/${github_repo}:latest

# Setup health check
cat > /usr/local/bin/health-check.sh <<'SCRIPT'
#!/bin/bash
if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    exit 0
else
    echo "Health check failed, restarting container..."
    docker restart humansa-ml
    exit 1
fi
SCRIPT
chmod +x /usr/local/bin/health-check.sh

# Add cron job for health check
echo "*/5 * * * * /usr/local/bin/health-check.sh" | crontab -

# Signal completion
aws ssm put-parameter \
    --name "/${project_name}/${environment}/instance/$INSTANCE_ID/status" \
    --value "ready" \
    --type String \
    --overwrite

echo "Humansa ML Server setup completed at $(date)"