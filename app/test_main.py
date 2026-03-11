"""Tests for the FastAPI application."""

import time

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)

def test_get_message():
    """Test the root endpoint returns correct structure."""
    before = int(time.time())
    response = client.get("/")
    after = int(time.time())

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Automate all the things!"
    assert before <= data["timestamp"] <= after


def test_health_check():
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
