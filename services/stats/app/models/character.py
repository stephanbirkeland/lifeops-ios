"""Character and stats models"""

from datetime import datetime
from typing import Optional, Any
from uuid import UUID
import uuid

from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.orm import relationship

from app.core.database import Base


# ===========================================
# SQLAlchemy Models
# ===========================================

class CharacterDB(Base):
    """Character profile - one per user"""
    __tablename__ = "characters"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(PGUUID(as_uuid=True), unique=True, nullable=False)
    name = Column(String, default="Adventurer")

    # Character progression
    level = Column(Integer, default=1)
    total_xp = Column(BigInteger, default=0)

    # Allocatable resources
    stat_points = Column(Integer, default=0)
    respec_tokens = Column(Integer, default=1)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=text("NOW()"))
    updated_at = Column(DateTime(timezone=True), server_default=text("NOW()"), onupdate=datetime.utcnow)

    # Relationships
    stats = relationship("CharacterStatDB", back_populates="character", cascade="all, delete-orphan")
    allocated_nodes = relationship("CharacterNodeDB", back_populates="character", cascade="all, delete-orphan")


class CharacterStatDB(Base):
    """Core attribute values for a character"""
    __tablename__ = "character_stats"

    character_id = Column(PGUUID(as_uuid=True), ForeignKey("characters.id", ondelete="CASCADE"), primary_key=True)
    stat_code = Column(String, primary_key=True)  # STR, INT, WIS, STA, CHA, LCK

    # Base value from passive growth
    base_value = Column(Integer, default=10)
    stat_xp = Column(BigInteger, default=0)

    # Bonus from tree allocations
    allocated_bonus = Column(Integer, default=0)

    # Relationship
    character = relationship("CharacterDB", back_populates="stats")


# ===========================================
# Pydantic Schemas
# ===========================================

class StatDetail(BaseModel):
    """Detailed stat information"""
    code: str
    name: str
    base: int
    allocated: int
    total: int
    xp: int
    xp_to_next: int
    level: int

    class Config:
        from_attributes = True


class CharacterStats(BaseModel):
    """All character stats"""
    STR: StatDetail
    INT: StatDetail
    WIS: StatDetail
    STA: StatDetail
    CHA: StatDetail
    LCK: StatDetail


class CharacterCreate(BaseModel):
    """Schema for creating a character"""
    user_id: UUID
    name: Optional[str] = "Adventurer"


class Character(BaseModel):
    """Character response schema"""
    id: UUID
    user_id: UUID
    name: str

    # Progression
    level: int
    total_xp: int
    xp_to_next_level: int
    level_progress: float  # percentage

    # Resources
    stat_points: int
    respec_tokens: int

    # Stats summary
    stats: dict[str, int]  # Just totals: {"STR": 15, "INT": 12, ...}

    # Counts
    allocated_nodes_count: int
    unlocked_skills_count: int

    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CharacterFull(Character):
    """Full character with detailed stats"""
    stats_detail: dict[str, StatDetail]
    allocated_node_codes: list[str]
    unlocked_skill_codes: list[str]
    derived_stats: dict[str, float]


# Stat name mapping
STAT_NAMES = {
    "STR": "Strength",
    "INT": "Intelligence",
    "WIS": "Wisdom",
    "STA": "Stamina",
    "CHA": "Charisma",
    "LCK": "Luck",
}
