"""Authentication models and schemas"""

from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID as PGUUID
import uuid

from app.core.database import Base


# ===========================================
# SQLAlchemy Models
# ===========================================

class UserDB(Base):
    """User authentication model"""
    __tablename__ = "users"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_superuser = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    last_login = Column(DateTime(timezone=True), nullable=True)


# ===========================================
# Pydantic Schemas
# ===========================================

class UserBase(BaseModel):
    """Base user schema"""
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr


class UserCreate(UserBase):
    """Schema for user registration"""
    password: str = Field(..., min_length=8, max_length=100)


class UserUpdate(BaseModel):
    """Schema for updating user"""
    email: Optional[EmailStr] = None
    password: Optional[str] = Field(None, min_length=8, max_length=100)
    is_active: Optional[bool] = None


class User(UserBase):
    """User schema for responses (no password)"""
    id: UUID
    is_active: bool
    is_superuser: bool
    created_at: datetime
    updated_at: datetime
    last_login: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserInDB(User):
    """User schema with hashed password (internal use only)"""
    hashed_password: str


# ===========================================
# Token Schemas
# ===========================================

class Token(BaseModel):
    """Token response"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenPayload(BaseModel):
    """JWT token payload"""
    sub: str  # subject (user_id)
    exp: int  # expiration time
    type: str  # token type: "access" or "refresh"


class RefreshTokenRequest(BaseModel):
    """Request schema for token refresh"""
    refresh_token: str


# ===========================================
# Auth Request Schemas
# ===========================================

class LoginRequest(BaseModel):
    """Login request schema"""
    username: str
    password: str


class PasswordChangeRequest(BaseModel):
    """Password change request"""
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=100)
