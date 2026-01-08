"""User profile model and schema"""

from datetime import datetime, time
from typing import Optional, Any
from uuid import UUID
from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Float, DateTime, Time, Integer
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
import uuid

from app.core.database import Base


# ===========================================
# SQLAlchemy Model
# ===========================================

class UserProfileDB(Base):
    """User profile and settings"""
    __tablename__ = "user_profile"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String)
    settings = Column(JSONB, default={})

    # Gamification state
    total_xp = Column(Integer, default=0)
    level = Column(Integer, default=1)

    # Goals
    target_wake_time = Column(Time, default=time(6, 0))
    target_bedtime = Column(Time, default=time(22, 30))
    target_screen_hours = Column(Float, default=3.0)
    target_gym_sessions = Column(Integer, default=3)

    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)


# ===========================================
# Pydantic Schemas
# ===========================================

class UserProfile(BaseModel):
    """User profile schema"""
    id: UUID
    name: Optional[str] = None
    settings: dict[str, Any] = Field(default_factory=dict)
    total_xp: int = 0
    level: int = 1
    target_wake_time: time = time(6, 0)
    target_bedtime: time = time(22, 30)
    target_screen_hours: float = 3.0
    target_gym_sessions: int = 3
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserProfileUpdate(BaseModel):
    """Schema for updating user profile"""
    name: Optional[str] = None
    settings: Optional[dict[str, Any]] = None
    target_wake_time: Optional[time] = None
    target_bedtime: Optional[time] = None
    target_screen_hours: Optional[float] = None
    target_gym_sessions: Optional[int] = None


class UserGoals(BaseModel):
    """User goals summary"""
    target_wake_time: time
    target_bedtime: time
    target_screen_hours: float
    target_gym_sessions: int
