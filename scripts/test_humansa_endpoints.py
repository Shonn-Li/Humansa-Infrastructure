#!/usr/bin/env python3
"""
Comprehensive testing script for Humansa ML Server endpoints
Tests all major endpoints with proper error handling and reporting
"""

import requests
import json
import sys
import time
from typing import Dict, Any, List
from datetime import datetime

# Configuration
BASE_URL = "https://humansa.youwo.ai"
TEST_USER_ID = "test-user-001"
TEST_CONVERSATION_ID = "test-conv-001"

# Color codes for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_test_header(test_name: str):
    """Print formatted test header"""
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Testing: {test_name}{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")

def print_result(success: bool, message: str, details: str = ""):
    """Print test result with color coding"""
    if success:
        print(f"{GREEN}✓ {message}{RESET}")
    else:
        print(f"{RED}✗ {message}{RESET}")
    if details:
        print(f"  {YELLOW}Details: {details}{RESET}")

def test_health_check() -> bool:
    """Test the health check endpoint"""
    print_test_header("Health Check")
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=10)
        if response.status_code == 200:
            print_result(True, "Health check passed", f"Response: {response.text}")
            return True
        else:
            print_result(False, "Health check failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Health check error", str(e))
        return False

def test_ping() -> bool:
    """Test the ping endpoint"""
    print_test_header("Ping Test")
    
    try:
        response = requests.get(f"{BASE_URL}/ping", timeout=10)
        if response.status_code == 200:
            print_result(True, "Ping successful", f"Response: {response.text}")
            return True
        else:
            print_result(False, "Ping failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Ping error", str(e))
        return False

def test_chat_completion() -> bool:
    """Test the chat completion endpoint"""
    print_test_header("Chat Completion (Non-Streaming)")
    
    payload = {
        "messages": [
            {"role": "system", "content": "You are a helpful medical assistant."},
            {"role": "user", "content": "What are the symptoms of the common cold?"}
        ],
        "model": "gpt-4.1-nano",
        "stream": False,
        "temperature": 0.7,
        "max_tokens": 150
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/v1/chat/completions",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            if "choices" in data and len(data["choices"]) > 0:
                content = data["choices"][0]["message"]["content"]
                print_result(True, "Chat completion successful", f"Response length: {len(content)} chars")
                return True
            else:
                print_result(False, "Unexpected response format", json.dumps(data)[:200])
                return False
        else:
            print_result(False, "Chat completion failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Chat completion error", str(e))
        return False

def test_streaming_chat() -> bool:
    """Test the streaming chat endpoint"""
    print_test_header("Chat Completion (Streaming)")
    
    payload = {
        "messages": [
            {"role": "user", "content": "Count from 1 to 5 slowly"}
        ],
        "model": "gpt-4.1-nano",
        "stream": True,
        "max_tokens": 50
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/v1/chat/completions",
            json=payload,
            headers={"Content-Type": "application/json"},
            stream=True,
            timeout=30
        )
        
        if response.status_code == 200:
            chunks_received = 0
            for line in response.iter_lines():
                if line:
                    chunks_received += 1
                    if chunks_received == 1:
                        print_result(True, "Streaming started", f"First chunk: {line.decode('utf-8')[:50]}...")
            
            if chunks_received > 0:
                print_result(True, f"Streaming completed", f"Received {chunks_received} chunks")
                return True
            else:
                print_result(False, "No streaming data received")
                return False
        else:
            print_result(False, "Streaming failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Streaming error", str(e))
        return False

def test_multi_agent() -> bool:
    """Test the multi-agent endpoint"""
    print_test_header("Multi-Agent Response")
    
    payload = {
        "user_id": TEST_USER_ID,
        "conversation_id": TEST_CONVERSATION_ID,
        "message": "I have a headache and fever. What should I do?",
        "agent_type": "medical_assistant",
        "stream": False
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/v1/multi-agent/response",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=45
        )
        
        if response.status_code == 200:
            data = response.json()
            print_result(True, "Multi-agent response successful", f"Response keys: {list(data.keys())}")
            return True
        else:
            print_result(False, "Multi-agent failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Multi-agent error", str(e))
        return False

def test_humansa_v2_chat() -> bool:
    """Test the Humansa V2 chat endpoint"""
    print_test_header("Humansa V2 Chat")
    
    payload = {
        "userId": TEST_USER_ID,
        "conversationId": TEST_CONVERSATION_ID,
        "message": "I need to schedule a checkup",
        "metadata": {
            "sessionType": "medical_consultation",
            "priority": "normal"
        }
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/v2/humansa/chat",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            print_result(True, "Humansa V2 chat successful", f"Response type: {type(data)}")
            return True
        else:
            print_result(False, "Humansa V2 chat failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Humansa V2 chat error", str(e))
        return False

def test_memory_status() -> bool:
    """Test the memory status endpoint"""
    print_test_header("Memory Service Status")
    
    try:
        response = requests.get(f"{BASE_URL}/v2/humansa/memory/status", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print_result(True, "Memory status retrieved", json.dumps(data)[:100])
            return True
        else:
            print_result(False, "Memory status failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Memory status error", str(e))
        return False

def test_debug_info() -> bool:
    """Test the debug info endpoint"""
    print_test_header("Debug Information")
    
    try:
        response = requests.get(f"{BASE_URL}/debug/info", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print_result(True, "Debug info retrieved", f"Keys: {list(data.keys())}")
            return True
        else:
            print_result(False, "Debug info failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Debug info error", str(e))
        return False

def test_appointment_search() -> bool:
    """Test appointment search endpoint"""
    print_test_header("Appointment Search")
    
    payload = {
        "userId": TEST_USER_ID,
        "specialty": "general",
        "dateRange": {
            "start": "2024-01-15",
            "end": "2024-01-31"
        }
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/v2/humansa/appointment/search",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=15
        )
        
        if response.status_code in [200, 404]:  # 404 is ok if no appointments found
            print_result(True, "Appointment search completed", f"Status: {response.status_code}")
            return True
        else:
            print_result(False, "Appointment search failed", f"Status: {response.status_code}")
            return False
    except Exception as e:
        print_result(False, "Appointment search error", str(e))
        return False

def run_all_tests():
    """Run all endpoint tests and generate summary"""
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Humansa ML Server Endpoint Testing{RESET}")
    print(f"{BLUE}Target: {BASE_URL}{RESET}")
    print(f"{BLUE}Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    
    tests = [
        ("Health Check", test_health_check),
        ("Ping", test_ping),
        ("Chat Completion", test_chat_completion),
        ("Streaming Chat", test_streaming_chat),
        ("Multi-Agent", test_multi_agent),
        ("Humansa V2 Chat", test_humansa_v2_chat),
        ("Memory Status", test_memory_status),
        ("Debug Info", test_debug_info),
        ("Appointment Search", test_appointment_search)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            success = test_func()
            results.append((test_name, success))
        except Exception as e:
            print(f"{RED}Unexpected error in {test_name}: {e}{RESET}")
            results.append((test_name, False))
        time.sleep(1)  # Small delay between tests
    
    # Print summary
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Test Summary{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    
    passed = sum(1 for _, success in results if success)
    failed = len(results) - passed
    
    for test_name, success in results:
        status = f"{GREEN}PASSED{RESET}" if success else f"{RED}FAILED{RESET}"
        print(f"  {test_name}: {status}")
    
    print(f"\n{BLUE}Results: {GREEN}{passed} passed{RESET}, {RED}{failed} failed{RESET}")
    print(f"{BLUE}Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{RESET}")
    
    # Exit with appropriate code
    sys.exit(0 if failed == 0 else 1)

if __name__ == "__main__":
    run_all_tests()