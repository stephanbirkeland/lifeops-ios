"""
Unit tests for health check endpoint.

These tests verify the basic health endpoint functionality
without requiring database or external services.
"""

import pytest
from fastapi.testclient import TestClient


@pytest.mark.unit
def test_health_endpoint_returns_200(client: TestClient):
    """Test that health endpoint returns 200 OK."""
    response = client.get("/health")
    assert response.status_code == 200


@pytest.mark.unit
def test_health_endpoint_returns_json(client: TestClient):
    """Test that health endpoint returns valid JSON."""
    response = client.get("/health")
    assert response.headers["content-type"] == "application/json"
    data = response.json()
    assert isinstance(data, dict)


@pytest.mark.unit
def test_health_endpoint_has_status_field(client: TestClient):
    """Test that health response includes status field."""
    response = client.get("/health")
    data = response.json()
    assert "status" in data
    assert data["status"] in ["healthy", "unhealthy", "degraded"]


@pytest.mark.unit
def test_health_endpoint_has_version(client: TestClient):
    """Test that health response includes version information."""
    response = client.get("/health")
    data = response.json()
    assert "version" in data
    assert isinstance(data["version"], str)
    assert len(data["version"]) > 0


@pytest.mark.unit
def test_health_endpoint_has_timestamp(client: TestClient):
    """Test that health response includes timestamp."""
    response = client.get("/health")
    data = response.json()
    assert "timestamp" in data
    # Verify it's a valid ISO timestamp
    from datetime import datetime
    timestamp = datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))
    assert timestamp is not None


@pytest.mark.unit
def test_health_endpoint_response_structure(client: TestClient):
    """Test complete health response structure."""
    response = client.get("/health")
    data = response.json()

    # Required fields
    required_fields = ["status", "version", "timestamp"]
    for field in required_fields:
        assert field in data, f"Missing required field: {field}"

    # Optional but expected fields
    expected_fields = ["database", "external_services"]
    # These might not be present in unit tests without DB
    # but document expected structure
    assert data["status"] == "healthy"
