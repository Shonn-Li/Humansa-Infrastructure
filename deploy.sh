#!/bin/bash
set -euo pipefail

# Humansa Infrastructure Deployment Script
# This script triggers GitHub Actions workflow for deploying updates

echo "🚀 Humansa Deployment Script"
echo "=========================="

# Check if required environment variables are set
if [ -z "${GITHUB_PAT:-}" ]; then
    echo "❌ Error: GITHUB_PAT environment variable is not set"
    echo "Please export GITHUB_PAT with a valid GitHub Personal Access Token"
    exit 1
fi

# Default values
GITHUB_REPO="${GITHUB_REPO:-youwoai/humansa-ml-server}"
ENVIRONMENT="${ENVIRONMENT:-production}"
ACTION="${1:-deploy}"

# Parse command line arguments
case "$ACTION" in
    deploy)
        EVENT_TYPE="deploy-humansa"
        echo "📦 Triggering deployment to $ENVIRONMENT environment..."
        ;;
    rollback)
        EVENT_TYPE="rollback-humansa"
        echo "⏪ Triggering rollback for $ENVIRONMENT environment..."
        ;;
    restart)
        EVENT_TYPE="restart-humansa"
        echo "🔄 Triggering service restart for $ENVIRONMENT environment..."
        ;;
    *)
        echo "❌ Unknown action: $ACTION"
        echo "Usage: $0 [deploy|rollback|restart]"
        exit 1
        ;;
esac

# Get current git commit hash if in a git repository
COMMIT_SHA="unknown"
if [ -d .git ]; then
    COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
fi

# Trigger GitHub Actions workflow
echo "🔗 Triggering GitHub Actions workflow..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPO/dispatches" \
    -d "{
        \"event_type\": \"$EVENT_TYPE\",
        \"client_payload\": {
            \"environment\": \"$ENVIRONMENT\",
            \"commit_sha\": \"$COMMIT_SHA\",
            \"triggered_by\": \"$(whoami)\",
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }
    }")

# Extract HTTP status code
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Check response
if [ "$HTTP_CODE" = "204" ]; then
    echo "✅ Successfully triggered $EVENT_TYPE workflow!"
    echo "📋 Details:"
    echo "   - Repository: $GITHUB_REPO"
    echo "   - Environment: $ENVIRONMENT"
    echo "   - Commit: $COMMIT_SHA"
    echo ""
    echo "🔍 Check workflow status at:"
    echo "   https://github.com/$GITHUB_REPO/actions"
else
    echo "❌ Failed to trigger workflow!"
    echo "   HTTP Status: $HTTP_CODE"
    if [ -n "$BODY" ]; then
        echo "   Response: $BODY"
    fi
    exit 1
fi

# Optional: Wait for workflow to start
if [ "${WAIT_FOR_START:-false}" = "true" ]; then
    echo ""
    echo "⏳ Waiting for workflow to start..."
    sleep 5
    
    # Check recent workflow runs
    RUNS=$(curl -s \
        -H "Authorization: token $GITHUB_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_REPO/actions/runs?event=repository_dispatch&per_page=1")
    
    RUN_URL=$(echo "$RUNS" | jq -r '.workflow_runs[0].html_url // empty')
    if [ -n "$RUN_URL" ]; then
        echo "🔗 Workflow started: $RUN_URL"
    fi
fi

echo ""
echo "🎉 Deployment trigger completed!"