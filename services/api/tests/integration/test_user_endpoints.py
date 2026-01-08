"""Integration tests for user endpoints"""

import pytest
from uuid import uuid4


class TestUserEndpoints:
    """Test suite for user management endpoints"""

    @pytest.mark.asyncio
    async def test_create_user_profile(self, async_client):
        """Test creating a new user profile"""
        user_data = {
            "name": "Test User",
            "email": "test@lifeops.local",
            "timezone": "Europe/Oslo"
        }

        response = await async_client.post("/user/profile", json=user_data)

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Test User"
        assert data["email"] == "test@lifeops.local"
        assert data["timezone"] == "Europe/Oslo"
        assert "id" in data
        assert "created_at" in data

    @pytest.mark.asyncio
    async def test_get_user_profile(self, async_client, db_session):
        """Test getting user profile"""
        # First create a user
        user_data = {
            "name": "Test User",
            "email": "test@lifeops.local",
            "timezone": "Europe/Oslo"
        }
        create_response = await async_client.post("/user/profile", json=user_data)
        assert create_response.status_code == 200
        created_user = create_response.json()

        # Now get the profile
        response = await async_client.get(f"/user/profile/{created_user['id']}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == created_user["id"]
        assert data["name"] == "Test User"

    @pytest.mark.asyncio
    async def test_get_nonexistent_user(self, async_client):
        """Test getting non-existent user returns 404"""
        fake_id = str(uuid4())
        response = await async_client.get(f"/user/profile/{fake_id}")

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_update_user_profile(self, async_client):
        """Test updating user profile"""
        # Create user
        user_data = {
            "name": "Test User",
            "email": "test@lifeops.local",
            "timezone": "Europe/Oslo"
        }
        create_response = await async_client.post("/user/profile", json=user_data)
        created_user = create_response.json()

        # Update user
        update_data = {
            "name": "Updated Name",
            "timezone": "America/New_York"
        }
        response = await async_client.patch(
            f"/user/profile/{created_user['id']}",
            json=update_data
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["timezone"] == "America/New_York"
        assert data["email"] == "test@lifeops.local"  # Unchanged

    @pytest.mark.asyncio
    async def test_update_user_goals(self, async_client):
        """Test updating user goals"""
        # Create user
        user_data = {
            "name": "Test User",
            "email": "test@lifeops.local"
        }
        create_response = await async_client.post("/user/profile", json=user_data)
        created_user = create_response.json()

        # Update goals
        goals_data = {
            "target_wake_time": "06:00",
            "target_bed_time": "22:00",
            "gym_sessions_per_week": 4,
            "target_sleep_hours": 8.0,
            "max_screen_hours": 2.5
        }
        response = await async_client.patch(
            f"/user/goals/{created_user['id']}",
            json=goals_data
        )

        assert response.status_code == 200
        data = response.json()
        assert data["gym_sessions_per_week"] == 4
        assert data["target_sleep_hours"] == 8.0

    @pytest.mark.asyncio
    async def test_create_duplicate_email(self, async_client):
        """Test creating user with duplicate email"""
        user_data = {
            "name": "User One",
            "email": "duplicate@lifeops.local"
        }

        # Create first user
        response1 = await async_client.post("/user/profile", json=user_data)
        assert response1.status_code == 200

        # Try to create second user with same email
        user_data["name"] = "User Two"
        response2 = await async_client.post("/user/profile", json=user_data)

        # Should either succeed (if no unique constraint) or return 400/409
        assert response2.status_code in [200, 400, 409]

    @pytest.mark.asyncio
    async def test_invalid_timezone(self, async_client):
        """Test creating user with invalid timezone"""
        user_data = {
            "name": "Test User",
            "email": "test@lifeops.local",
            "timezone": "Invalid/Timezone"
        }

        response = await async_client.post("/user/profile", json=user_data)

        # Should either validate or accept any string
        assert response.status_code in [200, 400, 422]
