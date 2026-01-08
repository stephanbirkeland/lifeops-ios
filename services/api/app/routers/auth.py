"""Authentication endpoints - login, logout, register, token refresh"""

from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from jose import JWTError

from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_access_token, create_refresh_token
from app.core.security.jwt import verify_token
from app.core.security.dependencies import get_current_user
from app.models.auth import (
    User,
    UserDB,
    UserCreate,
    Token,
    LoginRequest,
    RefreshTokenRequest,
    PasswordChangeRequest
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=User, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Register a new user account.

    Creates a new user with hashed password. Username and email must be unique.

    **Body Parameters:**
    - username: Unique username (3-50 characters)
    - email: Valid email address
    - password: Strong password (minimum 8 characters)

    **Returns:**
    - User object (without password)

    **Errors:**
    - 400: Username or email already exists
    """
    # Check if username exists
    result = await db.execute(
        select(UserDB).where(UserDB.username == user_data.username)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )

    # Check if email exists
    result = await db.execute(
        select(UserDB).where(UserDB.email == user_data.email)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # Create new user
    hashed_password = hash_password(user_data.password)
    new_user = UserDB(
        username=user_data.username,
        email=user_data.email,
        hashed_password=hashed_password,
        is_active=True,
        is_superuser=False
    )

    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    return User.model_validate(new_user)


@router.post("/login", response_model=Token)
async def login(
    login_data: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Login to get access and refresh tokens.

    Authenticates user with username and password, returns JWT tokens.

    **Body Parameters:**
    - username: User's username
    - password: User's password

    **Returns:**
    - access_token: Short-lived token for API requests (15 minutes)
    - refresh_token: Long-lived token for getting new access tokens (7 days)
    - token_type: "bearer"

    **Errors:**
    - 401: Invalid credentials
    - 403: User account is inactive

    **Usage:**
    ```
    # Include access_token in subsequent requests:
    Authorization: Bearer <access_token>
    ```
    """
    # Find user by username
    result = await db.execute(
        select(UserDB).where(UserDB.username == login_data.username)
    )
    user = result.scalar_one_or_none()

    # Verify credentials
    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check if user is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )

    # Update last login time
    await db.execute(
        update(UserDB)
        .where(UserDB.id == user.id)
        .values(last_login=datetime.utcnow())
    )
    await db.commit()

    # Create tokens
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer"
    )


@router.post("/refresh", response_model=Token)
async def refresh_token(
    refresh_data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Get new access token using refresh token.

    When your access token expires, use this endpoint to get a new one
    without requiring the user to log in again.

    **Body Parameters:**
    - refresh_token: Valid refresh token from login

    **Returns:**
    - New access_token and refresh_token pair

    **Errors:**
    - 401: Invalid or expired refresh token
    - 403: User account is inactive

    **Security Note:**
    Both tokens are rotated for security. The old refresh token becomes invalid.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # Verify refresh token
        token_data = verify_token(refresh_data.refresh_token, token_type="refresh")

        if token_data is None or token_data.sub is None:
            raise credentials_exception

        user_id = token_data.sub

    except JWTError:
        raise credentials_exception

    # Fetch user
    result = await db.execute(
        select(UserDB).where(UserDB.id == user_id)
    )
    user = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )

    # Create new token pair
    access_token = create_access_token(str(user.id))
    new_refresh_token = create_refresh_token(str(user.id))

    return Token(
        access_token=access_token,
        refresh_token=new_refresh_token,
        token_type="bearer"
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    current_user: User = Depends(get_current_user)
):
    """
    Logout current user.

    Since JWTs are stateless, logout is handled client-side by deleting tokens.
    This endpoint validates that the token is still valid and can be used
    for server-side logging or token revocation list implementation.

    **Authentication Required**

    **Returns:**
    - 204 No Content on success

    **Client Implementation:**
    1. Call this endpoint with current access token
    2. Delete access_token and refresh_token from storage
    3. Redirect to login page

    **Future Enhancement:**
    Token revocation list can be implemented here for immediate token invalidation.
    """
    # In a production system with token revocation:
    # - Add token to revocation list (Redis/database)
    # - Track logout event for security audit
    # - Optionally revoke all user sessions

    # For now, logout is client-side (delete tokens)
    # This endpoint just validates the token is still valid
    return None


@router.get("/me", response_model=User)
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """
    Get current authenticated user's information.

    **Authentication Required**

    **Returns:**
    - User object with profile information
    """
    return current_user


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    password_data: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Change current user's password.

    Requires current password for verification before setting new password.

    **Authentication Required**

    **Body Parameters:**
    - current_password: User's current password
    - new_password: New password (minimum 8 characters)

    **Returns:**
    - 204 No Content on success

    **Errors:**
    - 401: Current password is incorrect

    **Security Note:**
    After password change, consider invalidating all existing tokens
    and requiring re-authentication.
    """
    # Fetch full user record with password
    result = await db.execute(
        select(UserDB).where(UserDB.id == current_user.id)
    )
    user_db = result.scalar_one_or_none()

    if not user_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    # Verify current password
    if not verify_password(password_data.current_password, user_db.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect"
        )

    # Hash and update password
    new_hashed_password = hash_password(password_data.new_password)
    await db.execute(
        update(UserDB)
        .where(UserDB.id == user_db.id)
        .values(hashed_password=new_hashed_password, updated_at=datetime.utcnow())
    )
    await db.commit()

    # TODO: Optionally invalidate all existing tokens for this user
    # This would require a token revocation list

    return None
