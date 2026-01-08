"""Health-related database models and schemas"""

from datetime import datetime, date
from typing import Optional, Any
from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Float, DateTime, Date, Integer, JSON
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base


# ===========================================
# SQLAlchemy Models
# ===========================================

class HealthMetricDB(Base):
    """Time-series health metrics from Oura"""
    __tablename__ = "health_metrics"

    time = Column(DateTime(timezone=True), primary_key=True)
    metric_type = Column(String, primary_key=True)
    value = Column(Float)
    metric_metadata = Column(JSONB, default={})  # Note: 'metadata' is reserved in SQLAlchemy
    source = Column(String, default="oura")


class DailySummaryDB(Base):
    """Daily aggregated data from Oura"""
    __tablename__ = "daily_summaries"

    date = Column(Date, primary_key=True)
    sleep_score = Column(Integer)
    readiness_score = Column(Integer)
    activity_score = Column(Integer)
    sleep_data = Column(JSONB, default={})
    readiness_data = Column(JSONB, default={})
    activity_data = Column(JSONB, default={})
    synced_at = Column(DateTime(timezone=True), default=datetime.utcnow)


# ===========================================
# Pydantic Schemas
# ===========================================

class HealthMetric(BaseModel):
    """Health metric schema"""
    time: datetime
    metric_type: str
    value: float
    metadata: dict[str, Any] = Field(default_factory=dict)
    source: str = "oura"

    class Config:
        from_attributes = True


class DailySummary(BaseModel):
    """Daily summary schema"""
    date: date
    sleep_score: Optional[int] = None
    readiness_score: Optional[int] = None
    activity_score: Optional[int] = None
    sleep_data: dict[str, Any] = Field(default_factory=dict)
    readiness_data: dict[str, Any] = Field(default_factory=dict)
    activity_data: dict[str, Any] = Field(default_factory=dict)
    synced_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class OuraSleepData(BaseModel):
    """Oura sleep data structure"""
    score: Optional[int] = None
    total_sleep_duration: Optional[int] = None  # seconds
    rem_sleep_duration: Optional[int] = None
    deep_sleep_duration: Optional[int] = None
    light_sleep_duration: Optional[int] = None
    awake_time: Optional[int] = None
    sleep_efficiency: Optional[int] = None
    bedtime_start: Optional[datetime] = None
    bedtime_end: Optional[datetime] = None
    average_heart_rate: Optional[float] = None
    lowest_heart_rate: Optional[int] = None
    average_hrv: Optional[int] = None


class OuraReadinessData(BaseModel):
    """Oura readiness data structure"""
    score: Optional[int] = None
    temperature_deviation: Optional[float] = None
    previous_day_activity: Optional[str] = None
    sleep_balance: Optional[str] = None
    previous_night: Optional[str] = None
    activity_balance: Optional[str] = None
    resting_heart_rate: Optional[int] = None
    hrv_balance: Optional[str] = None
    recovery_index: Optional[str] = None


class OuraActivityData(BaseModel):
    """Oura activity data structure"""
    score: Optional[int] = None
    steps: Optional[int] = None
    active_calories: Optional[int] = None
    total_calories: Optional[int] = None
    sedentary_time: Optional[int] = None  # seconds
    low_activity_time: Optional[int] = None
    medium_activity_time: Optional[int] = None
    high_activity_time: Optional[int] = None
    movement_every_hour: Optional[float] = None
    meet_daily_targets: Optional[int] = None
