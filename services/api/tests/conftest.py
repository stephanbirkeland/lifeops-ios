"""
Pytest configuration and fixtures for LifeOps API tests.

This module provides shared fixtures for database access, API client,
and common test data.
"""

import asyncio
import os
from typing import AsyncGenerator, Generator
from uuid import uuid4

import pytest
import pytest_asyncio
from fastapi.testclient import TestClient
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool

from app.main import app
from app.core.database import Base, get_db
from app.core.config import settings


# =============================================================================
# Test Database Configuration
# =============================================================================

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://lifeops:lifeops_test@localhost:5432/lifeops_test"
)


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """
    Create an event loop for the entire test session.
    Required for pytest-asyncio to work properly.
    """
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def test_engine():
    """
    Create a test database engine for the entire test session.
    Uses NullPool to avoid connection pool issues during testing.
    """
    engine = create_async_engine(
        TEST_DATABASE_URL,
        poolclass=NullPool,
        echo=False,  # Set to True for SQL debugging
    )

    # Create all tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    # Drop all tables after tests
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """
    Create a fresh database session for each test.
    Automatically rolls back after each test to keep tests isolated.
    """
    async_session_maker = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.rollback()


# =============================================================================
# API Client Fixtures
# =============================================================================

@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    """
    Synchronous test client for simple API tests.
    Uses TestClient which handles lifespan events automatically.
    """
    with TestClient(app) as c:
        yield c


@pytest_asyncio.fixture
async def async_client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """
    Async test client for testing async endpoints and WebSocket.
    """
    # Override the database dependency
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

    # Clean up dependency override
    app.dependency_overrides.clear()


# =============================================================================
# Test Data Fixtures
# =============================================================================

@pytest.fixture
def test_user_id() -> str:
    """Generate a consistent test user ID."""
    return "test-user-123"


@pytest.fixture
def test_user_data(test_user_id: str) -> dict:
    """Sample user data for testing."""
    return {
        "id": test_user_id,
        "email": "test@lifeops.local",
        "name": "Test User",
        "timezone": "Europe/Oslo",
        "created_at": "2026-01-01T00:00:00Z",
    }


@pytest.fixture
def test_oura_sleep_data() -> dict:
    """Sample Oura sleep data for testing."""
    return {
        "id": "sleep-123",
        "day": "2026-01-08",
        "score": 85,
        "contributors": {
            "deep_sleep": 90,
            "efficiency": 95,
            "latency": 85,
            "rem_sleep": 80,
            "restfulness": 75,
            "timing": 85,
            "total_sleep": 90,
        },
        "period": 0,
        "readiness": {
            "score": 82,
            "temperature_deviation": -0.2,
        },
        "bedtime_start": "2026-01-07T22:30:00Z",
        "bedtime_end": "2026-01-08T06:30:00Z",
        "total_sleep_duration": 28800,  # 8 hours in seconds
    }


@pytest.fixture
def test_activity_data() -> dict:
    """Sample activity log data for testing."""
    return {
        "activity_type": "gym_session",
        "duration_minutes": 60,
        "metadata": {
            "type": "strength_training",
            "exercises": ["bench_press", "squats", "deadlift"],
            "intensity": "high",
        },
        "timestamp": "2026-01-08T07:00:00Z",
    }


@pytest.fixture
def test_timeline_item() -> dict:
    """Sample timeline item for testing."""
    return {
        "code": "morning_routine",
        "title": "Morning Routine",
        "description": "Complete morning routine",
        "type": "routine",
        "scheduled_time": "06:30",
        "duration_minutes": 30,
        "repeats": "daily",
        "enabled": True,
    }


# =============================================================================
# Mock External Services
# =============================================================================

@pytest.fixture
def mock_oura_api(monkeypatch):
    """
    Mock Oura API responses to avoid hitting real API during tests.
    """
    class MockOuraResponse:
        def __init__(self, data, status_code=200):
            self.data = data
            self.status_code = status_code

        def json(self):
            return self.data

        def raise_for_status(self):
            if self.status_code >= 400:
                raise Exception(f"HTTP {self.status_code}")

    async def mock_get(*args, **kwargs):
        # Return mock sleep data
        return MockOuraResponse({
            "data": [
                {
                    "id": "test-sleep-session",
                    "day": "2026-01-08",
                    "score": 85,
                }
            ]
        })

    # Monkeypatch httpx.AsyncClient.get
    monkeypatch.setattr("httpx.AsyncClient.get", mock_get)

    return mock_get


@pytest.fixture
def mock_stats_service(monkeypatch):
    """
    Mock Stats Service API responses.
    """
    class MockStatsResponse:
        def __init__(self, data, status_code=200):
            self.data = data
            self.status_code = status_code

        def json(self):
            return self.data

    async def mock_post(*args, **kwargs):
        return MockStatsResponse({
            "success": True,
            "xp_granted": {"STR": 50, "STA": 20},
        })

    monkeypatch.setattr("httpx.AsyncClient.post", mock_post)

    return mock_post


# =============================================================================
# Cleanup Helpers
# =============================================================================

@pytest.fixture(autouse=True)
async def cleanup_database(db_session: AsyncSession):
    """
    Automatically clean up database after each test.
    This runs after every test to ensure clean state.
    """
    yield
    # Rollback is handled by db_session fixture
    # Additional cleanup can be added here if needed


# =============================================================================
# Parametrize Helpers
# =============================================================================

def pytest_configure(config):
    """Add custom markers."""
    config.addinivalue_line("markers", "unit: Unit tests (fast, isolated)")
    config.addinivalue_line("markers", "integration: Integration tests")
    config.addinivalue_line("markers", "slow: Slow tests (may take >1s)")
    config.addinivalue_line("markers", "oura: Tests requiring Oura API")
    config.addinivalue_line("markers", "stats: Tests requiring Stats Service")
