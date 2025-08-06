#!/bin/bash

# Quick test script for Humansa ML Server
# This script performs basic connectivity and functionality tests

set -e

BASE_URL="https://humansa.youwo.ai"

echo "=========================================="
echo "Humansa ML Server Quick Test"
echo "Target: $BASE_URL"
echo "=========================================="

# Function to print colored output
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "\033[92m✓ $2\033[0m"
    else
        echo -e "\033[91m✗ $2\033[0m"
    fi
}

# Test 1: Health Check
echo -e "\n1. Testing Health Check..."
if curl -s -f -o /dev/null -w "%{http_code}" "$BASE_URL/health" | grep -q "200"; then
    print_result 0 "Health check passed"
else
    print_result 1 "Health check failed"
fi

# Test 2: Ping
echo -e "\n2. Testing Ping..."
PING_RESPONSE=$(curl -s "$BASE_URL/ping" 2>/dev/null || echo "Failed")
if [ "$PING_RESPONSE" != "Failed" ]; then
    print_result 0 "Ping successful: $PING_RESPONSE"
else
    print_result 1 "Ping failed"
fi

# Test 3: Simple Chat Completion
echo -e "\n3. Testing Chat Completion..."
CHAT_RESPONSE=$(curl -s -X POST "$BASE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Say hello"}],
    "model": "gpt-4.1-nano",
    "stream": false,
    "max_tokens": 50
  }' 2>/dev/null || echo "Failed")

if echo "$CHAT_RESPONSE" | grep -q "choices"; then
    print_result 0 "Chat completion successful"
    echo "  Response preview: $(echo "$CHAT_RESPONSE" | head -c 100)..."
else
    print_result 1 "Chat completion failed"
    echo "  Error: $CHAT_RESPONSE"
fi

# Test 4: Debug Info
echo -e "\n4. Testing Debug Info..."
DEBUG_RESPONSE=$(curl -s "$BASE_URL/debug/info" 2>/dev/null || echo "Failed")
if echo "$DEBUG_RESPONSE" | grep -q "environment"; then
    print_result 0 "Debug info retrieved"
else
    print_result 1 "Debug info failed"
fi

# Test 5: Memory Status
echo -e "\n5. Testing Memory Service..."
MEMORY_RESPONSE=$(curl -s "$BASE_URL/v2/humansa/memory/status" 2>/dev/null || echo "Failed")
if [ "$MEMORY_RESPONSE" != "Failed" ]; then
    print_result 0 "Memory service accessible"
else
    print_result 1 "Memory service not accessible"
fi

echo -e "\n=========================================="
echo "Quick test completed!"
echo "For comprehensive testing, run:"
echo "  python3 scripts/test_humansa_endpoints.py"
echo "=========================================="