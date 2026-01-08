"""Timeline models - rolling task/event feed"""

from datetime import datetime, date, time, timedelta
from typing import Optional, Any
from uuid import UUID
from enum import Enum

from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Integer, Boolean, Date, Time, DateTime, ForeignKey, text, ARRAY
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
import uuid as uuid_lib

from app.core.database import Base


# ===========================================
# Enums
# ===========================================

class ScheduleType(str, Enum):
    DAILY = "daily"
    WEEKDAYS = "weekdays"
    WEEKENDS = "weekends"
    WEEKLY = "weekly"
    SPECIFIC_DAYS = "specific_days"
    ONCE = "once"


class OverrideType(str, Enum):
    POSTPONE = "postpone"
    SKIP = "skip"
    RESCHEDULE = "reschedule"


class ItemCategory(str, Enum):
    TASK = "task"
    CHORE = "chore"
    HABIT = "habit"
    REMINDER = "reminder"
    EVENT = "event"


class PostponeTarget(str, Enum):
    """Smart postpone targets"""
    LUNCH = "lunch"
    AFTERNOON = "afternoon"
    AFTER_WORK = "after_work"
    EVENING = "evening"
    TONIGHT = "tonight"
    TOMORROW = "tomorrow"
    TOMORROW_MORNING = "tomorrow_morning"
    NEXT_WEEK = "next_week"
    CUSTOM = "custom"


# ===========================================
# SQLAlchemy Models
# ===========================================

class TimeAnchorDB(Base):
    """Time reference points (lunch, after_work, etc.)"""
    __tablename__ = "time_anchors"

    code = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    default_time = Column(Time, nullable=False)
    description = Column(String)


class TimelineItemDB(Base):
    """Timeline item definitions"""
    __tablename__ = "timeline_items"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid_lib.uuid4)
    code = Column(String, unique=True, nullable=False)
    name = Column(String, nullable=False)
    description = Column(String)
    icon = Column(String)

    # Scheduling
    schedule_type = Column(String, default="daily")
    schedule_days = Column(ARRAY(Integer), default=[])
    anchor = Column(String, ForeignKey("time_anchors.code"))
    time_offset = Column(Integer, default=0)
    exact_time = Column(Time)

    # Time window
    window_minutes = Column(Integer, default=60)

    # For one-time items
    scheduled_date = Column(Date)

    # Integration
    stat_rewards = Column(JSONB, default={})

    # Priority and display
    priority = Column(Integer, default=5)
    category = Column(String, default="task")

    # State
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=text("NOW()"))
    updated_at = Column(DateTime(timezone=True), server_default=text("NOW()"))


class TimelineOverrideDB(Base):
    """Postponements and reschedules"""
    __tablename__ = "timeline_overrides"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid_lib.uuid4)
    item_id = Column(PGUUID(as_uuid=True), ForeignKey("timeline_items.id", ondelete="CASCADE"))
    original_date = Column(Date, nullable=False)

    override_type = Column(String, nullable=False)

    new_date = Column(Date)
    new_time = Column(Time)
    new_anchor = Column(String, ForeignKey("time_anchors.code"))

    reason = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=text("NOW()"))


class TimelineCompletionDB(Base):
    """Completed timeline items"""
    __tablename__ = "timeline_completions"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid_lib.uuid4)
    item_id = Column(PGUUID(as_uuid=True), ForeignKey("timeline_items.id", ondelete="CASCADE"))
    completed_date = Column(Date, nullable=False)
    completed_at = Column(DateTime(timezone=True), server_default=text("NOW()"))

    notes = Column(String)
    duration_minutes = Column(Integer)
    xp_granted = Column(JSONB, default={})


class TimelineStreakDB(Base):
    """Streak tracking for timeline items"""
    __tablename__ = "timeline_streaks"

    item_id = Column(PGUUID(as_uuid=True), ForeignKey("timeline_items.id", ondelete="CASCADE"), primary_key=True)
    current_streak = Column(Integer, default=0)
    best_streak = Column(Integer, default=0)
    last_completed = Column(Date)
    updated_at = Column(DateTime(timezone=True), server_default=text("NOW()"))


class CalendarEventDB(Base):
    """External calendar events"""
    __tablename__ = "calendar_events"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid_lib.uuid4)
    external_id = Column(String)
    source = Column(String, nullable=False)

    title = Column(String, nullable=False)
    description = Column(String)
    location = Column(String)

    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True))
    all_day = Column(Boolean, default=False)

    event_type = Column(String, default="event")

    prep_minutes = Column(Integer, default=0)
    travel_minutes = Column(Integer, default=0)

    synced_at = Column(DateTime(timezone=True), server_default=text("NOW()"))
    raw_data = Column(JSONB, default={})


# ===========================================
# Pydantic Schemas
# ===========================================

class TimeAnchor(BaseModel):
    """Time anchor schema"""
    code: str
    name: str
    default_time: time
    description: Optional[str] = None

    class Config:
        from_attributes = True


class TimelineItemCreate(BaseModel):
    """Create a timeline item"""
    code: str
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None

    schedule_type: ScheduleType = ScheduleType.DAILY
    schedule_days: list[int] = Field(default_factory=list)  # 0=Mon, 6=Sun
    anchor: Optional[str] = None
    time_offset: int = 0  # minutes from anchor
    exact_time: Optional[time] = None

    window_minutes: int = 60
    scheduled_date: Optional[date] = None  # for 'once' type

    stat_rewards: dict[str, int] = Field(default_factory=dict)
    priority: int = 5
    category: ItemCategory = ItemCategory.TASK


class TimelineItem(BaseModel):
    """Timeline item response"""
    id: UUID
    code: str
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None

    schedule_type: str
    schedule_days: list[int]
    anchor: Optional[str] = None
    time_offset: int
    exact_time: Optional[time] = None

    window_minutes: int
    scheduled_date: Optional[date] = None

    stat_rewards: dict[str, int]
    priority: int
    category: str

    is_active: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TimelineFeedItem(BaseModel):
    """Single item in the timeline feed"""
    id: UUID
    code: str
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    category: str

    # Computed for this instance
    scheduled_time: time
    window_end: time
    status: str  # overdue, active, upcoming, completed

    # Streak info
    current_streak: int = 0
    best_streak: int = 0

    # If completed
    completed_at: Optional[datetime] = None

    # Stats
    stat_rewards: dict[str, int] = Field(default_factory=dict)


class TimelineFeed(BaseModel):
    """The rolling timeline feed"""
    now: datetime
    date: date
    window_hours: int

    items: list[TimelineFeedItem]

    # Summary
    completed_today: int
    total_today: int
    completion_rate: float

    # Hidden items
    hidden_count: int
    next_hidden_at: Optional[time] = None


class PostponeRequest(BaseModel):
    """Request to postpone an item"""
    target: PostponeTarget
    custom_date: Optional[date] = None
    custom_time: Optional[time] = None
    reason: Optional[str] = None


class PostponeResponse(BaseModel):
    """Response after postponing"""
    success: bool
    item_code: str
    original_date: date
    new_date: date
    new_time: time
    message: str


class CompleteRequest(BaseModel):
    """Request to complete an item"""
    notes: Optional[str] = None
    duration_minutes: Optional[int] = None


class CompleteResponse(BaseModel):
    """Response after completing"""
    success: bool
    item_code: str
    completed_at: datetime
    xp_granted: dict[str, int]
    new_streak: int
    message: str


class CalendarEvent(BaseModel):
    """Calendar event in feed"""
    id: UUID
    title: str
    description: Optional[str] = None
    location: Optional[str] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    all_day: bool
    event_type: str
    source: str

    class Config:
        from_attributes = True
