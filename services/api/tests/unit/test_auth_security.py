"""
Unit tests for authentication security utilities.

Tests password hashing, JWT token creation/validation.
"""

import pytest
from datetime import timedelta
from jose import JWTError

from app.core.security.password import hash_password, verify_password, needs_update
from app.core.security.jwt import (
    create_access_token,
    create_refresh_token,
    verify_token,
    decode_token_unsafe
)


@pytest.mark.unit
class TestPasswordHashing:
    """Test password hashing and verification."""

    def test_hash_password(self):
        """Test password hashing produces different hashes each time."""
        password = "my_secure_password"
        hash1 = hash_password(password)
        hash2 = hash_password(password)

        # Should produce different hashes (due to salt)
        assert hash1 != hash2
        assert len(hash1) > 0
        assert hash1.startswith("$2b$")  # bcrypt prefix

    def test_verify_password_success(self):
        """Test password verification with correct password."""
        password = "my_secure_password"
        hashed = hash_password(password)

        assert verify_password(password, hashed) is True

    def test_verify_password_failure(self):
        """Test password verification with incorrect password."""
        password = "my_secure_password"
        hashed = hash_password(password)

        assert verify_password("wrong_password", hashed) is False

    def test_verify_password_empty(self):
        """Test password verification with empty password."""
        password = "my_secure_password"
        hashed = hash_password(password)

        assert verify_password("", hashed) is False

    def test_needs_update(self):
        """Test checking if password hash needs update."""
        password = "my_secure_password"
        hashed = hash_password(password)

        # New hash should not need update
        assert needs_update(hashed) is False


@pytest.mark.unit
class TestJWTTokens:
    """Test JWT token creation and validation."""

    def test_create_access_token(self):
        """Test access token creation."""
        user_id = "user-123"
        token = create_access_token(user_id)

        assert len(token) > 0
        assert isinstance(token, str)

        # Decode to verify contents
        payload = decode_token_unsafe(token)
        assert payload["sub"] == user_id
        assert payload["type"] == "access"
        assert "exp" in payload
        assert "iat" in payload

    def test_create_refresh_token(self):
        """Test refresh token creation."""
        user_id = "user-123"
        token = create_refresh_token(user_id)

        assert len(token) > 0
        assert isinstance(token, str)

        # Decode to verify contents
        payload = decode_token_unsafe(token)
        assert payload["sub"] == user_id
        assert payload["type"] == "refresh"
        assert "exp" in payload
        assert "iat" in payload

    def test_create_token_custom_expiration(self):
        """Test token creation with custom expiration."""
        user_id = "user-123"
        custom_delta = timedelta(minutes=30)
        token = create_access_token(user_id, expires_delta=custom_delta)

        assert len(token) > 0

    def test_verify_access_token(self):
        """Test access token verification."""
        user_id = "user-123"
        token = create_access_token(user_id)

        token_data = verify_token(token, token_type="access")

        assert token_data is not None
        assert token_data.sub == user_id
        assert token_data.type == "access"

    def test_verify_refresh_token(self):
        """Test refresh token verification."""
        user_id = "user-123"
        token = create_refresh_token(user_id)

        token_data = verify_token(token, token_type="refresh")

        assert token_data is not None
        assert token_data.sub == user_id
        assert token_data.type == "refresh"

    def test_verify_token_wrong_type(self):
        """Test verification fails when token type doesn't match."""
        user_id = "user-123"
        access_token = create_access_token(user_id)

        # Try to verify access token as refresh token
        with pytest.raises(JWTError):
            verify_token(access_token, token_type="refresh")

    def test_verify_invalid_token(self):
        """Test verification fails with invalid token."""
        invalid_token = "invalid.token.here"

        with pytest.raises(JWTError):
            verify_token(invalid_token, token_type="access")

    def test_verify_tampered_token(self):
        """Test verification fails with tampered token."""
        user_id = "user-123"
        token = create_access_token(user_id)

        # Tamper with token by changing last character
        tampered_token = token[:-1] + ("a" if token[-1] != "a" else "b")

        with pytest.raises(JWTError):
            verify_token(tampered_token, token_type="access")

    def test_decode_token_unsafe(self):
        """Test unsafe token decoding (no verification)."""
        user_id = "user-123"
        token = create_access_token(user_id)

        payload = decode_token_unsafe(token)

        assert payload["sub"] == user_id
        assert payload["type"] == "access"
        assert "exp" in payload
        assert "iat" in payload

    def test_tokens_are_different(self):
        """Test that access and refresh tokens are different."""
        user_id = "user-123"
        access_token = create_access_token(user_id)
        refresh_token = create_refresh_token(user_id)

        assert access_token != refresh_token

        # Decode both to verify they have different types
        access_payload = decode_token_unsafe(access_token)
        refresh_payload = decode_token_unsafe(refresh_token)

        assert access_payload["type"] == "access"
        assert refresh_payload["type"] == "refresh"

    def test_multiple_tokens_same_user(self):
        """Test creating multiple tokens for same user produces unique tokens."""
        user_id = "user-123"
        token1 = create_access_token(user_id)
        token2 = create_access_token(user_id)

        # Should be different due to different iat (issued at time)
        assert token1 != token2

        # Both should verify successfully
        verify_token(token1, token_type="access")
        verify_token(token2, token_type="access")
