"""Stat tree models - nodes, edges, allocations"""

from datetime import datetime
from typing import Optional, Any
from uuid import UUID
import uuid
from enum import Enum

from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB, ARRAY
from sqlalchemy.orm import relationship

from app.core.database import Base


# ===========================================
# Enums
# ===========================================

class NodeType(str, Enum):
    ORIGIN = "origin"       # Starting node
    MINOR = "minor"         # Small bonus (+1 stat, +2%)
    NOTABLE = "notable"     # Named node with larger bonus
    KEYSTONE = "keystone"   # Major effect with trade-offs
    SKILL = "skill"         # Unlocks an ability


class TreeBranch(str, Enum):
    ORIGIN = "ORIGIN"
    STR = "STR"
    INT = "INT"
    WIS = "WIS"
    STA = "STA"
    CHA = "CHA"
    LCK = "LCK"
    HYBRID = "HYBRID"  # Cross-branch nodes


# ===========================================
# SQLAlchemy Models
# ===========================================

class StatNodeDB(Base):
    """Stat tree node definition"""
    __tablename__ = "stat_nodes"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String, unique=True, nullable=False)
    name = Column(String, nullable=False)
    description = Column(String)

    # Classification
    node_type = Column(String, nullable=False, default="minor")
    tree_branch = Column(String)  # STR, INT, WIS, STA, CHA, LCK, HYBRID

    # Visual position for tree rendering
    position_x = Column(Float, default=0)
    position_y = Column(Float, default=0)

    # Requirements
    required_points = Column(Integer, default=1)
    prerequisite_nodes = Column(ARRAY(PGUUID(as_uuid=True)), default=[])

    # Effects (JSONB for flexibility)
    effects = Column(JSONB, default=[])

    # Metadata
    icon = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=text("NOW()"))


class StatNodeEdgeDB(Base):
    """Connections between nodes in the tree"""
    __tablename__ = "stat_node_edges"

    from_node_id = Column(PGUUID(as_uuid=True), ForeignKey("stat_nodes.id"), primary_key=True)
    to_node_id = Column(PGUUID(as_uuid=True), ForeignKey("stat_nodes.id"), primary_key=True)
    bidirectional = Column(Boolean, default=True)


class CharacterNodeDB(Base):
    """Character's allocated nodes"""
    __tablename__ = "character_nodes"

    character_id = Column(PGUUID(as_uuid=True), ForeignKey("characters.id", ondelete="CASCADE"), primary_key=True)
    node_id = Column(PGUUID(as_uuid=True), ForeignKey("stat_nodes.id"), primary_key=True)
    allocated_at = Column(DateTime(timezone=True), server_default=text("NOW()"))

    # Relationships
    character = relationship("CharacterDB", back_populates="allocated_nodes")


# ===========================================
# Pydantic Schemas
# ===========================================

class NodeEffect(BaseModel):
    """Effect applied by a node"""
    type: str  # stat_bonus, stat_percent, derived_bonus, xp_multiplier, unlock_skill, special
    stat: Optional[str] = None
    derived: Optional[str] = None
    skill_code: Optional[str] = None
    value: Optional[float] = None
    value_percent: Optional[float] = None
    domain: Optional[str] = None  # For xp_multiplier
    code: Optional[str] = None  # For special effects
    description: Optional[str] = None


class StatNode(BaseModel):
    """Stat node response schema"""
    id: UUID
    code: str
    name: str
    description: Optional[str] = None

    node_type: str
    tree_branch: Optional[str] = None

    position_x: float = 0
    position_y: float = 0

    required_points: int = 1
    prerequisite_codes: list[str] = []

    effects: list[NodeEffect] = []

    icon: Optional[str] = None
    is_allocated: bool = False  # Set based on character

    class Config:
        from_attributes = True


class TreeResponse(BaseModel):
    """Full tree structure response"""
    nodes: list[StatNode]
    edges: list[tuple[str, str]]  # (from_code, to_code)
    branches: dict[str, list[str]]  # branch -> node codes


class AllocateRequest(BaseModel):
    """Request to allocate points"""
    character_id: UUID
    node_codes: list[str]


class AllocateResponse(BaseModel):
    """Response after allocation"""
    success: bool
    points_spent: int
    points_remaining: int
    nodes_allocated: list[str]
    stat_changes: dict[str, dict[str, int]]  # {"STR": {"before": 10, "after": 15}}
    new_effects: list[NodeEffect]
    errors: list[str] = []


class RespecRequest(BaseModel):
    """Request to respec (reset allocations)"""
    character_id: UUID


class RespecResponse(BaseModel):
    """Response after respec"""
    success: bool
    nodes_removed: int
    points_refunded: int
    respec_tokens_remaining: int
