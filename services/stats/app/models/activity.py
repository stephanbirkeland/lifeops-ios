"""Activity logging models"""

from datetime import datetime
from typing import Optional, Any
from uuid import UUID
import uuid

from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB

from app.core.database import Base


# ===========================================
# SQLAlchemy Models
# ===========================================

class ActivityLogDB(Base):
    """Activity log - events that grant stat XP"""
    __tablename__ = "activity_log"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    character_id = Column(PGUUID(as_uuid=True), ForeignKey("characters.id"))

    # Activity details
    activity_type = Column(String, nullable=False)
    activity_data = Column(JSONB, default={})
    source = Column(String, nullable=False)  # lifeops, challengemode, manual
    source_ref = Column(String)  # External reference ID

    # XP granted
    xp_grants = Column(JSONB, default={})  # {"STR": 50, "STA": 20}

    # Timestamps
    activity_time = Column(DateTime(timezone=True), nullable=False)
    logged_at = Column(DateTime(timezone=True), server_default=text("NOW()"))


# ===========================================
# Pydantic Schemas
# ===========================================

class XPGrant(BaseModel):
    """XP granted per stat"""
    STR: int = 0
    INT: int = 0
    WIS: int = 0
    STA: int = 0
    CHA: int = 0
    LCK: int = 0


class ActivityCreate(BaseModel):
    """Schema for logging an activity"""
    user_id: UUID  # Will be resolved to character_id
    activity_type: str
    activity_data: dict[str, Any] = Field(default_factory=dict)
    source: str = "manual"
    source_ref: Optional[str] = None
    activity_time: datetime

    # Optional: override calculated XP
    custom_xp: Optional[dict[str, int]] = None


class Activity(BaseModel):
    """Activity response schema"""
    id: UUID
    character_id: UUID
    activity_type: str
    activity_data: dict[str, Any]
    source: str
    source_ref: Optional[str]
    xp_grants: dict[str, int]
    activity_time: datetime
    logged_at: datetime

    class Config:
        from_attributes = True


class ActivityResponse(BaseModel):
    """Response after logging activity"""
    success: bool
    activity_id: UUID
    xp_granted: dict[str, int]
    stat_level_ups: list[str]  # Stats that leveled up
    character_level_up: bool
    new_level: Optional[int] = None
    message: str


class ActivityBatchCreate(BaseModel):
    """Batch activity logging"""
    activities: list[ActivityCreate]


class ActivityBatchResponse(BaseModel):
    """Response for batch logging"""
    success: bool
    processed: int
    total_xp: dict[str, int]
    stat_level_ups: list[str]
    character_level_up: bool
