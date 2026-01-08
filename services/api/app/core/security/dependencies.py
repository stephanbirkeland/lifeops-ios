"""FastAPI dependencies for authentication and authorization"""

from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security.jwt import verify_token
from app.models.auth import User, UserDB

# HTTP Bearer token scheme for Swagger UI
security = HTTPBearer(
    scheme_name="Bearer Token",
    description="Enter your JWT access token"
)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Dependency to get the current authenticated user from JWT token.

    This dependency:
    1. Extracts the JWT token from the Authorization header
    2. Validates the token
    3. Retrieves the user from the database
    4. Checks if the user is active

    Args:
        credentials: HTTP Bearer credentials from request header
        db: Database session

    Returns:
        Authenticated User object

    Raises:
        HTTPException 401: If token is invalid, expired, or user not found
        HTTPException 403: If user is inactive

    Usage:
        @router.get("/protected")
        async def protected_route(current_user: User = Depends(get_current_user)):
            return {"user_id": current_user.id}
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # Extract token from credentials
        token = credentials.credentials

        # Verify and decode token
        token_data = verify_token(token, token_type="access")

        if token_data is None or token_data.sub is None:
            raise credentials_exception

        user_id = token_data.sub

    except JWTError:
        raise credentials_exception

    # Fetch user from database
    result = await db.execute(
        select(UserDB).where(UserDB.id == user_id)
    )
    user_db = result.scalar_one_or_none()

    if user_db is None:
        raise credentials_exception

    # Check if user is active
    if not user_db.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )

    return User.model_validate(user_db)


async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Dependency to get current active user (redundant check, but explicit).

    This is an alias for get_current_user since that already checks is_active.
    Kept for semantic clarity in route definitions.

    Args:
        current_user: User from get_current_user dependency

    Returns:
        Active User object

    Raises:
        HTTPException 403: If user is inactive
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    return current_user


async def get_current_superuser(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Dependency to require superuser privileges.

    Use this dependency for admin-only endpoints.

    Args:
        current_user: User from get_current_user dependency

    Returns:
        User object with superuser privileges

    Raises:
        HTTPException 403: If user is not a superuser

    Usage:
        @router.delete("/admin/users/{user_id}")
        async def delete_user(
            user_id: UUID,
            admin: User = Depends(get_current_superuser)
        ):
            # Only superusers can access this
            pass
    """
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough privileges"
        )
    return current_user


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False)),
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """
    Dependency to optionally get the current user.

    Returns the user if a valid token is provided, otherwise returns None.
    Does not raise an error if no token is provided.

    This is useful for endpoints that behave differently when authenticated
    but are still accessible to anonymous users.

    Args:
        credentials: Optional HTTP Bearer credentials
        db: Database session

    Returns:
        User object if authenticated, None if not

    Usage:
        @router.get("/posts")
        async def list_posts(user: Optional[User] = Depends(get_optional_user)):
            if user:
                # Show personalized feed
                return get_user_feed(user.id)
            else:
                # Show public feed
                return get_public_feed()
    """
    if credentials is None:
        return None

    try:
        token = credentials.credentials
        token_data = verify_token(token, token_type="access")

        if token_data is None or token_data.sub is None:
            return None

        result = await db.execute(
            select(UserDB).where(UserDB.id == token_data.sub)
        )
        user_db = result.scalar_one_or_none()

        if user_db is None or not user_db.is_active:
            return None

        return User.model_validate(user_db)

    except (JWTError, Exception):
        return None
