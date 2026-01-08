"""JWT token creation and validation"""

from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt

from app.core.config import settings
from app.models.auth import TokenPayload


def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create a JWT access token for a user.

    Args:
        user_id: User ID to encode in the token
        expires_delta: Optional custom expiration time

    Returns:
        Encoded JWT token string

    Examples:
        >>> token = create_access_token("user-123")
        >>> len(token) > 0
        True
    """
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.access_token_expire_minutes)

    to_encode = {
        "sub": user_id,
        "exp": expire,
        "type": "access",
        "iat": datetime.utcnow()
    }

    encoded_jwt = jwt.encode(
        to_encode,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm
    )
    return encoded_jwt


def create_refresh_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create a JWT refresh token for a user.

    Refresh tokens are longer-lived and can be used to obtain new access tokens.

    Args:
        user_id: User ID to encode in the token
        expires_delta: Optional custom expiration time

    Returns:
        Encoded JWT refresh token string

    Examples:
        >>> token = create_refresh_token("user-123")
        >>> len(token) > 0
        True
    """
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days)

    to_encode = {
        "sub": user_id,
        "exp": expire,
        "type": "refresh",
        "iat": datetime.utcnow()
    }

    encoded_jwt = jwt.encode(
        to_encode,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm
    )
    return encoded_jwt


def verify_token(token: str, token_type: str = "access") -> Optional[TokenPayload]:
    """
    Verify and decode a JWT token.

    Args:
        token: JWT token string to verify
        token_type: Expected token type ("access" or "refresh")

    Returns:
        TokenPayload if valid, None if invalid

    Raises:
        JWTError: If token is invalid or expired

    Examples:
        >>> token = create_access_token("user-123")
        >>> payload = verify_token(token, "access")
        >>> payload.sub
        'user-123'
    """
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm]
        )

        # Validate token type
        if payload.get("type") != token_type:
            raise JWTError(f"Invalid token type. Expected {token_type}")

        # Create TokenPayload object for validation
        token_data = TokenPayload(
            sub=payload.get("sub"),
            exp=payload.get("exp"),
            type=payload.get("type")
        )

        return token_data

    except JWTError:
        raise


def decode_token_unsafe(token: str) -> dict:
    """
    Decode a JWT token without verification (for debugging only).

    WARNING: This should only be used for debugging purposes.
    Always use verify_token() for production authentication.

    Args:
        token: JWT token string

    Returns:
        Decoded token payload as dict
    """
    return jwt.get_unverified_claims(token)
