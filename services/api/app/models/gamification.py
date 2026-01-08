"""Gamification models and schemas"""

from datetime import datetime, date
from typing import Optional, Any
from uuid import UUID
from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Float, DateTime, Date, Integer, Boolean
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
import uuid

from app.core.database import Base


# ===========================================
# SQLAlchemy Models
# ===========================================

class StreakDB(Base):
    """Streak tracking"""
    __tablename__ = "streaks"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    streak_type = Column(String, unique=True, nullable=False)
    current_count = Column(Integer, default=0)
    best_count = Column(Integer, default=0)
    last_date = Column(Date)
    freeze_tokens = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)


class AchievementDB(Base):
    """Achievement tracking"""
    __tablename__ = "achievements"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String, unique=True, nullable=False)
    name = Column(String, nullable=False)
    description = Column(String)
    tier = Column(String, default="bronze")
    xp_reward = Column(Integer, default=0)
    progress = Column(Integer, default=0)
    target = Column(Integer, default=1)
    unlocked_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)


class DailyScoreDB(Base):
    """Calculated daily scores"""
    __tablename__ = "daily_scores"

    date = Column(Date, primary_key=True)
    life_score = Column(Float)
    sleep_score = Column(Float)
    activity_score = Column(Float)
    worklife_score = Column(Float)
    habits_score = Column(Float)
    xp_earned = Column(Integer, default=0)
    calculated_at = Column(DateTime(timezone=True), default=datetime.utcnow)


class GamificationEventDB(Base):
    """Gamification event log"""
    __tablename__ = "gamification_events"

    time = Column(DateTime(timezone=True), primary_key=True, default=datetime.utcnow)
    event_type = Column(String, primary_key=True, nullable=False)
    xp_earned = Column(Integer, default=0)
    details = Column(JSONB, default={})


# ===========================================
# Pydantic Schemas
# ===========================================

class Streak(BaseModel):
    """Streak schema"""
    id: UUID
    streak_type: str
    current_count: int = 0
    best_count: int = 0
    last_date: Optional[date] = None
    freeze_tokens: int = 0

    class Config:
        from_attributes = True


class Achievement(BaseModel):
    """Achievement schema"""
    id: UUID
    code: str
    name: str
    description: Optional[str] = None
    tier: str = "bronze"
    xp_reward: int = 0
    progress: int = 0
    target: int = 1
    unlocked_at: Optional[datetime] = None
    is_unlocked: bool = False

    @property
    def progress_percent(self) -> float:
        if self.target == 0:
            return 100.0
        return min(100.0, (self.progress / self.target) * 100)

    class Config:
        from_attributes = True


class DailyScore(BaseModel):
    """Daily score schema"""
    date: date
    life_score: float
    sleep_score: float
    activity_score: float
    worklife_score: float
    habits_score: float
    xp_earned: int = 0

    class Config:
        from_attributes = True


class GamificationEvent(BaseModel):
    """Gamification event schema"""
    time: datetime
    event_type: str
    xp_earned: int = 0
    details: dict[str, Any] = Field(default_factory=dict)

    class Config:
        from_attributes = True


class XPInfo(BaseModel):
    """XP and level information"""
    total_xp: int = 0
    level: int = 1
    xp_for_current_level: int = 0
    xp_for_next_level: int = 1000
    progress_to_next: float = 0.0  # percentage
    today_xp: int = 0


class TodayResponse(BaseModel):
    """Response for /api/today endpoint"""
    date: date
    life_score: float
    domains: dict[str, float]
    xp: XPInfo
    streaks: dict[str, int]
    recent_achievements: list[Achievement] = []
    message: Optional[str] = None
