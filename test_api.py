#!/usr/bin/env python3
"""
Integration tests for EC2 Provisioner API

IMPORTANT: These tests require the FastAPI server to be running on localhost:8000
Start the server before running tests:
    uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

Run tests with:
    pytest test_api.py -v
"""

import requests
import json
import sys
import pytest

BASE_URL = "http://localhost:8000"

def test_health():
    """Test health endpoint"""
    print("Testing GET /health...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert response.json() == {"status": "ok"}, "Unexpected response format"

def test_list_instances():
    """Test list instances endpoint"""
    print("\nTesting GET /instances...")
    response = requests.get(f"{BASE_URL}/instances")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert "instances" in response.json(), "Expected 'instances' key in response"

def test_create_instance_invalid():
    """Test create instance with invalid data (should fail free tier check)"""
    print("\nTesting POST /instances with invalid instance type...")
    payload = {
        "name": "test-instance",
        "ami": "ami-0c02fb55956c7d316",
        "instance_type": "t2.large",  # Not free tier
        "storage_gb": 8
    }
    response = requests.post(f"{BASE_URL}/instances", json=payload)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    assert response.status_code == 400, f"Expected 400 for invalid instance type, got {response.status_code}"

def test_create_instance_invalid_ami():
    """Test create instance with invalid AMI (should fail free tier check)"""
    print("\nTesting POST /instances with invalid AMI...")
    payload = {
        "name": "test-instance",
        "ami": "ami-invalid12345",  # Not free tier
        "instance_type": "t2.micro",
        "storage_gb": 8
    }
    response = requests.post(f"{BASE_URL}/instances", json=payload)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    assert response.status_code == 400, f"Expected 400 for invalid AMI, got {response.status_code}"

def test_swagger_docs():
    """Test Swagger/OpenAPI docs"""
    print("\nTesting GET /docs (Swagger UI)...")
    response = requests.get(f"{BASE_URL}/docs")
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        print("✓ Swagger UI available at http://localhost:8000/docs")
    assert response.status_code == 200, f"Expected 200 for Swagger UI, got {response.status_code}"

if __name__ == "__main__":
    # Run tests locally with proper output
    print("=" * 60)
    print("EC2 Provisioner API — Local Testing")
    print("=" * 60)
    print("Use 'pytest test_api.py -v' for automated testing")
    print("=" * 60)
