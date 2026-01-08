"""Integration tests for health check endpoints"""

import pytest
from datetime import datetime


class TestHealthEndpoints:
    """Test suite for health check and root endpoints"""

    @pytest.mark.asyncio
    async def test_root_endpoint(self, async_client):
        """Test root endpoint returns service information"""
        response = await async_client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert data["service"] == "LifeOps API"
        assert "version" in data
        assert "docs" in data
        assert "health" in data

    @pytest.mark.asyncio
    async def test_health_check_endpoint(self, async_client):
        """Test health check endpoint returns status"""
        response = await async_client.get("/health")

        assert response.status_code == 200
        data = response.json()

        # Verify structure
        assert "status" in data
        assert "timestamp" in data
        assert "version" in data
        assert "environment" in data
        assert "services" in data

        # Verify timestamp is recent
        timestamp = datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))
        now = datetime.utcnow()
        assert (now - timestamp.replace(tzinfo=None)).total_seconds() < 5

        # Verify services are checked
        assert "database" in data["services"]
        assert "oura" in data["services"]

        # Database should be healthy in test environment
        assert data["services"]["database"] == "healthy"

    @pytest.mark.asyncio
    async def test_health_check_database_connection(self, async_client, db_session):
        """Test health check verifies database connectivity"""
        response = await async_client.get("/health")

        assert response.status_code == 200
        data = response.json()

        # Database should be accessible
        assert data["services"]["database"] == "healthy"
        assert data["status"] in ["healthy", "degraded"]

    @pytest.mark.asyncio
    async def test_health_check_oura_status(self, async_client):
        """Test health check reports Oura configuration status"""
        response = await async_client.get("/health")

        assert response.status_code == 200
        data = response.json()

        # Oura should report configuration status
        assert data["services"]["oura"] in ["configured", "not_configured"]
