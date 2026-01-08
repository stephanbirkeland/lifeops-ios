"""Derived stats and skills models"""

from datetime import datetime
from typing import Optional, Any
from uuid import UUID
import uuid

from pydantic import BaseModel
from sqlalchemy import Column, String, Integer, Boolean, DateTime, Interval, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB, ARRAY

from app.core.database import Base


# ===========================================
# SQLAlchemy Models
# ===========================================

class DerivedStatDB(Base):
    """Derived stat definitions - calculated from core stats"""
    __tablename__ = "derived_stats"

    code = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(String)

    # Formula for calculation
    formula = Column(String, nullable=False)  # e.g., "STR * 1.5 + INT * 0.5"

    # Source stats (for UI hints)
    source_stats = Column(ARRAY(String), default=[])

    is_active = Column(Boolean, default=True)


class SkillDB(Base):
    """Skill definitions - unlockable abilities"""
    __tablename__ = "skills"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String, unique=True, nullable=False)
    name = Column(String, nullable=False)
    description = Column(String)

    # Unlock requirements
    required_node_id = Column(PGUUID(as_uuid=True), ForeignKey("stat_nodes.id"))
    stat_requirements = Column(JSONB, default={})  # {"STR": 20, "STA": 15}

    # Skill properties
    effects = Column(JSONB, default={})
    cooldown = Column(Interval)

    is_active = Column(Boolean, default=True)


class CharacterSkillDB(Base):
    """Character's unlocked skills"""
    __tablename__ = "character_skills"

    character_id = Column(PGUUID(as_uuid=True), ForeignKey("characters.id", ondelete="CASCADE"), primary_key=True)
    skill_id = Column(PGUUID(as_uuid=True), ForeignKey("skills.id"), primary_key=True)
    unlocked_at = Column(DateTime(timezone=True), server_default=text("NOW()"))
    times_used = Column(Integer, default=0)
    last_used = Column(DateTime(timezone=True))


# ===========================================
# Pydantic Schemas
# ===========================================

class DerivedStat(BaseModel):
    """Derived stat schema"""
    code: str
    name: str
    description: Optional[str] = None
    formula: str
    source_stats: list[str] = []
    value: Optional[float] = None  # Calculated for a character

    class Config:
        from_attributes = True


class Skill(BaseModel):
    """Skill schema"""
    id: UUID
    code: str
    name: str
    description: Optional[str] = None
    stat_requirements: dict[str, int] = {}
    effects: dict[str, Any] = {}
    cooldown_seconds: Optional[int] = None
    is_unlocked: bool = False
    can_unlock: bool = False  # Based on current stats
    times_used: int = 0

    class Config:
        from_attributes = True
