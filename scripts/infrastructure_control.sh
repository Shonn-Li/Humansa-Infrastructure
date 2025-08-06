#!/bin/bash

# Humansa Infrastructure Control Script
# Quick commands for destroy/restore operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    color=$1
    message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check infrastructure status
check_status() {
    print_color "$BLUE" "Checking infrastructure status..."
    
    # Check EC2 instances
    INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=humansa" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text 2>/dev/null || echo "")
    
    # Check RDS
    RDS=$(aws rds describe-db-instances \
        --query "DBInstances[?contains(DBInstanceIdentifier, 'humansa')].DBInstanceIdentifier" \
        --output text 2>/dev/null || echo "")
    
    # Check ALB
    ALB=$(aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?contains(LoadBalancerName, 'humansa')].LoadBalancerArn" \
        --output text 2>/dev/null || echo "")
    
    echo ""
    if [ -n "$INSTANCES" ] || [ -n "$RDS" ] || [ -n "$ALB" ]; then
        print_color "$GREEN" "✅ Infrastructure is RUNNING"
        [ -n "$INSTANCES" ] && echo "   EC2 Instances: $(echo $INSTANCES | wc -w)"
        [ -n "$RDS" ] && echo "   RDS Database: Active"
        [ -n "$ALB" ] && echo "   Load Balancer: Active"
        echo "   URL: https://humansa.youwo.ai"
        
        # Calculate daily cost
        print_color "$YELLOW" "   Estimated daily cost: \$1.50"
    else
        print_color "$YELLOW" "⚠️  Infrastructure is DESTROYED"
        echo "   No active resources found"
        print_color "$GREEN" "   Estimated daily cost: \$0.30"
    fi
    echo ""
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_color "$RED" "⚠️  WARNING: This will destroy all Humansa infrastructure!"
    echo ""
    read -p "Type 'DESTROY-HUMANSA' to confirm: " confirmation
    
    if [ "$confirmation" != "DESTROY-HUMANSA" ]; then
        print_color "$YELLOW" "Destruction cancelled"
        exit 1
    fi
    
    print_color "$BLUE" "Creating backup and destroying infrastructure..."
    
    # Create destroy tag
    TAG="destroy-$(date +%Y%m%d-%H%M%S)"
    git tag "$TAG"
    git push origin "$TAG"
    
    print_color "$GREEN" "✅ Destruction initiated with tag: $TAG"
    echo "Monitor progress at: https://github.com/Shonn-Li/Humansa-Infrastructure/actions"
}

# Function to restore infrastructure
restore_infrastructure() {
    print_color "$BLUE" "Restoring infrastructure..."
    
    # List recent snapshots
    print_color "$YELLOW" "Available database snapshots:"
    aws rds describe-db-snapshots \
        --query "DBSnapshots[?contains(DBSnapshotIdentifier, 'humansa')].[DBSnapshotIdentifier,SnapshotCreateTime]" \
        --output table | head -10
    
    echo ""
    read -p "Enter snapshot ID to restore (or press Enter for fresh database): " snapshot_id
    
    # Create restore tag
    TAG="restore-$(date +%Y%m%d-%H%M%S)"
    
    if [ -n "$snapshot_id" ]; then
        # Would need to pass snapshot_id through commit message or other mechanism
        git tag -a "$TAG" -m "snapshot:$snapshot_id"
    else
        git tag "$TAG"
    fi
    
    git push origin "$TAG"
    
    print_color "$GREEN" "✅ Restoration initiated with tag: $TAG"
    echo "Monitor progress at: https://github.com/Shonn-Li/Humansa-Infrastructure/actions"
}

# Function to list snapshots
list_snapshots() {
    print_color "$BLUE" "Database Snapshots:"
    aws rds describe-db-snapshots \
        --query "DBSnapshots[?contains(DBSnapshotIdentifier, 'humansa')].{ID:DBSnapshotIdentifier,Created:SnapshotCreateTime,SizeGB:AllocatedStorage,Status:Status}" \
        --output table
}

# Function to estimate costs
estimate_costs() {
    print_color "$BLUE" "Cost Estimation:"
    echo ""
    echo "When RUNNING (ultra-optimized):"
    echo "  - EC2 (2x t3.micro):     \$0.62/day (\$18.60/month)"
    echo "  - RDS (db.t3.micro):      \$0.50/day (\$15.00/month)"
    echo "  - ALB:                    \$0.55/day (\$16.50/month)"
    echo "  - EBS (2x 20GB):         \$0.13/day (\$4.00/month)"
    echo "  - Data Transfer:          ~\$0.20/day (\$6.00/month)"
    print_color "$GREEN" "  TOTAL:                    ~\$1.50/day (\$45/month)"
    echo ""
    echo "When DESTROYED:"
    echo "  - S3 (terraform state):   \$0.01/day (\$0.30/month)"
    echo "  - RDS Snapshots:          \$0.05/day (\$1.50/month)"
    echo "  - Route53:                \$0.50/month"
    print_color "$GREEN" "  TOTAL:                    ~\$0.10/day (\$3/month)"
    echo ""
    print_color "$YELLOW" "💰 SAVINGS when destroyed: ~\$1.40/day (\$42/month)"
}

# Function to quick test
quick_test() {
    print_color "$BLUE" "Testing infrastructure endpoints..."
    
    # Test health endpoint
    if curl -s -f -o /dev/null -w "%{http_code}" "https://humansa.youwo.ai/health" | grep -q "200"; then
        print_color "$GREEN" "✅ Health check: PASS"
    else
        print_color "$RED" "❌ Health check: FAIL"
    fi
    
    # Test ping
    PING=$(curl -s "https://humansa.youwo.ai/ping" 2>/dev/null || echo "Failed")
    if [ "$PING" != "Failed" ]; then
        print_color "$GREEN" "✅ Ping test: PASS"
    else
        print_color "$RED" "❌ Ping test: FAIL"
    fi
}

# Main menu
show_menu() {
    print_color "$BLUE" "========================================="
    print_color "$BLUE" "    Humansa Infrastructure Control"
    print_color "$BLUE" "========================================="
    echo ""
    echo "1) Check Status"
    echo "2) Destroy Infrastructure"
    echo "3) Restore Infrastructure"
    echo "4) List Snapshots"
    echo "5) Estimate Costs"
    echo "6) Quick Test"
    echo "7) Exit"
    echo ""
    read -p "Select option [1-7]: " choice
}

# Main loop
while true; do
    clear
    show_menu
    
    case $choice in
        1)
            check_status
            ;;
        2)
            destroy_infrastructure
            ;;
        3)
            restore_infrastructure
            ;;
        4)
            list_snapshots
            ;;
        5)
            estimate_costs
            ;;
        6)
            quick_test
            ;;
        7)
            print_color "$GREEN" "Goodbye!"
            exit 0
            ;;
        *)
            print_color "$RED" "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done