"""
Integration tests for authentication endpoints.

Tests the full authentication flow including:
- User registration
- Login/logout
- Token refresh
- Password changes
- Protected route access
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.auth import UserDB
from app.core.security import hash_password


@pytest.fixture
async def test_user(db_session: AsyncSession):
    """Create a test user in the database."""
    user = UserDB(
        username="testuser",
        email="test@example.com",
        hashed_password=hash_password("Test123!Pass"),
        is_active=True,
        is_superuser=False
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def test_superuser(db_session: AsyncSession):
    """Create a test superuser in the database."""
    user = UserDB(
        username="admin",
        email="admin@example.com",
        hashed_password=hash_password("Admin123!Pass"),
        is_active=True,
        is_superuser=True
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.mark.integration
@pytest.mark.asyncio
class TestUserRegistration:
    """Test user registration endpoint."""

    async def test_register_new_user(self, async_client: AsyncClient):
        """Test successful user registration."""
        response = await async_client.post(
            "/auth/register",
            json={
                "username": "newuser",
                "email": "new@example.com",
                "password": "SecurePass123!"
            }
        )

        assert response.status_code == 201
        data = response.json()
        assert data["username"] == "newuser"
        assert data["email"] == "new@example.com"
        assert "id" in data
        assert "hashed_password" not in data  # Should not expose password
        assert data["is_active"] is True
        assert data["is_superuser"] is False

    async def test_register_duplicate_username(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test registration fails with duplicate username."""
        response = await async_client.post(
            "/auth/register",
            json={
                "username": "testuser",  # Same as test_user
                "email": "different@example.com",
                "password": "SecurePass123!"
            }
        )

        assert response.status_code == 400
        assert "username already registered" in response.json()["detail"].lower()

    async def test_register_duplicate_email(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test registration fails with duplicate email."""
        response = await async_client.post(
            "/auth/register",
            json={
                "username": "different",
                "email": "test@example.com",  # Same as test_user
                "password": "SecurePass123!"
            }
        )

        assert response.status_code == 400
        assert "email already registered" in response.json()["detail"].lower()

    async def test_register_invalid_email(self, async_client: AsyncClient):
        """Test registration fails with invalid email."""
        response = await async_client.post(
            "/auth/register",
            json={
                "username": "newuser",
                "email": "not-an-email",
                "password": "SecurePass123!"
            }
        )

        assert response.status_code == 422  # Validation error

    async def test_register_short_password(self, async_client: AsyncClient):
        """Test registration fails with password < 8 characters."""
        response = await async_client.post(
            "/auth/register",
            json={
                "username": "newuser",
                "email": "new@example.com",
                "password": "short"
            }
        )

        assert response.status_code == 422  # Validation error


@pytest.mark.integration
@pytest.mark.asyncio
class TestLogin:
    """Test login endpoint."""

    async def test_login_success(self, async_client: AsyncClient, test_user: UserDB):
        """Test successful login returns tokens."""
        response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert len(data["access_token"]) > 0
        assert len(data["refresh_token"]) > 0

    async def test_login_wrong_password(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test login fails with incorrect password."""
        response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "WrongPassword123!"
            }
        )

        assert response.status_code == 401
        assert "incorrect username or password" in response.json()["detail"].lower()

    async def test_login_nonexistent_user(self, async_client: AsyncClient):
        """Test login fails with non-existent username."""
        response = await async_client.post(
            "/auth/login",
            json={
                "username": "nonexistent",
                "password": "SomePassword123!"
            }
        )

        assert response.status_code == 401

    async def test_login_inactive_user(
        self, async_client: AsyncClient, db_session: AsyncSession
    ):
        """Test login fails for inactive user."""
        # Create inactive user
        inactive_user = UserDB(
            username="inactive",
            email="inactive@example.com",
            hashed_password=hash_password("Test123!Pass"),
            is_active=False,
            is_superuser=False
        )
        db_session.add(inactive_user)
        await db_session.commit()

        response = await async_client.post(
            "/auth/login",
            json={
                "username": "inactive",
                "password": "Test123!Pass"
            }
        )

        assert response.status_code == 403
        assert "inactive" in response.json()["detail"].lower()


@pytest.mark.integration
@pytest.mark.asyncio
class TestTokenRefresh:
    """Test token refresh endpoint."""

    async def test_refresh_token_success(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test successful token refresh."""
        # First login to get tokens
        login_response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )
        refresh_token = login_response.json()["refresh_token"]

        # Refresh token
        response = await async_client.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token}
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        # New tokens should be different
        assert data["refresh_token"] != refresh_token

    async def test_refresh_invalid_token(self, async_client: AsyncClient):
        """Test refresh fails with invalid token."""
        response = await async_client.post(
            "/auth/refresh",
            json={"refresh_token": "invalid_token_12345"}
        )

        assert response.status_code == 401

    async def test_refresh_access_token_fails(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test refresh fails when using access token instead of refresh token."""
        # Login to get access token
        login_response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )
        access_token = login_response.json()["access_token"]

        # Try to refresh with access token (should fail)
        response = await async_client.post(
            "/auth/refresh",
            json={"refresh_token": access_token}
        )

        assert response.status_code == 401


@pytest.mark.integration
@pytest.mark.asyncio
class TestProtectedEndpoints:
    """Test protected endpoints require authentication."""

    async def test_access_protected_endpoint_with_token(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test accessing protected endpoint with valid token."""
        # Login
        login_response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )
        access_token = login_response.json()["access_token"]

        # Access protected endpoint
        response = await async_client.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {access_token}"}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"

    async def test_access_protected_endpoint_without_token(
        self, async_client: AsyncClient
    ):
        """Test accessing protected endpoint without token fails."""
        response = await async_client.get("/auth/me")

        assert response.status_code == 403  # Forbidden (no credentials)

    async def test_access_protected_endpoint_invalid_token(
        self, async_client: AsyncClient
    ):
        """Test accessing protected endpoint with invalid token fails."""
        response = await async_client.get(
            "/auth/me",
            headers={"Authorization": "Bearer invalid_token_12345"}
        )

        assert response.status_code == 401


@pytest.mark.integration
@pytest.mark.asyncio
class TestPasswordChange:
    """Test password change endpoint."""

    async def test_change_password_success(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test successful password change."""
        # Login
        login_response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )
        access_token = login_response.json()["access_token"]

        # Change password
        response = await async_client.post(
            "/auth/change-password",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "current_password": "Test123!Pass",
                "new_password": "NewPassword123!"
            }
        )

        assert response.status_code == 204

        # Verify can login with new password
        new_login = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "NewPassword123!"
            }
        )
        assert new_login.status_code == 200

        # Verify cannot login with old password
        old_login = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )
        assert old_login.status_code == 401

    async def test_change_password_wrong_current(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test password change fails with incorrect current password."""
        # Login
        login_response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )
        access_token = login_response.json()["access_token"]

        # Try to change password with wrong current password
        response = await async_client.post(
            "/auth/change-password",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "current_password": "WrongPassword123!",
                "new_password": "NewPassword123!"
            }
        )

        assert response.status_code == 401


@pytest.mark.integration
@pytest.mark.asyncio
class TestLogout:
    """Test logout endpoint."""

    async def test_logout_success(
        self, async_client: AsyncClient, test_user: UserDB
    ):
        """Test successful logout."""
        # Login
        login_response = await async_client.post(
            "/auth/login",
            json={
                "username": "testuser",
                "password": "Test123!Pass"
            }
        )
        access_token = login_response.json()["access_token"]

        # Logout
        response = await async_client.post(
            "/auth/logout",
            headers={"Authorization": f"Bearer {access_token}"}
        )

        assert response.status_code == 204

    async def test_logout_without_token(self, async_client: AsyncClient):
        """Test logout fails without token."""
        response = await async_client.post("/auth/logout")

        assert response.status_code == 403
