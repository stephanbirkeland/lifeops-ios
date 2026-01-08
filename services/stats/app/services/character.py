"""Character service - CRUD operations and stat management"""

from uuid import UUID
from typing import Optional
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.character import (
    CharacterDB, CharacterStatDB,
    Character, CharacterCreate, CharacterFull, StatDetail, STAT_NAMES
)
from app.models.tree import CharacterNodeDB, StatNodeDB
from app.models.skills import CharacterSkillDB, SkillDB, DerivedStatDB
from app.services.progression import ProgressionService


class CharacterService:
    """Service for character operations"""

    CORE_STATS = ["STR", "INT", "WIS", "STA", "CHA", "LCK"]

    def __init__(self, db: AsyncSession):
        self.db = db
        self.progression = ProgressionService()

    async def create_character(self, data: CharacterCreate) -> Character:
        """Create a new character with initial stats"""
        # Check if user already has a character
        existing = await self.get_by_user_id(data.user_id)
        if existing:
            raise ValueError(f"User {data.user_id} already has a character")

        # Create character
        character = CharacterDB(
            user_id=data.user_id,
            name=data.name or "Adventurer",
            level=1,
            total_xp=0,
            stat_points=0,
            respec_tokens=1
        )
        self.db.add(character)
        await self.db.flush()

        # Create initial stats (all start at base 10)
        for stat_code in self.CORE_STATS:
            stat = CharacterStatDB(
                character_id=character.id,
                stat_code=stat_code,
                base_value=10,
                stat_xp=0,
                allocated_bonus=0
            )
            self.db.add(stat)

        await self.db.commit()
        await self.db.refresh(character)

        return await self.get_character_response(character.id)

    async def get_by_id(self, character_id: UUID) -> Optional[CharacterDB]:
        """Get character by ID"""
        result = await self.db.execute(
            select(CharacterDB)
            .options(selectinload(CharacterDB.stats))
            .options(selectinload(CharacterDB.allocated_nodes))
            .where(CharacterDB.id == character_id)
        )
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: UUID) -> Optional[CharacterDB]:
        """Get character by user ID"""
        result = await self.db.execute(
            select(CharacterDB)
            .options(selectinload(CharacterDB.stats))
            .options(selectinload(CharacterDB.allocated_nodes))
            .where(CharacterDB.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_character_response(self, character_id: UUID) -> Optional[Character]:
        """Get character formatted for API response"""
        character = await self.get_by_id(character_id)
        if not character:
            return None

        # Get stats totals
        stats_dict = {}
        for stat in character.stats:
            stats_dict[stat.stat_code] = stat.base_value + stat.allocated_bonus

        # Get counts
        nodes_count = len(character.allocated_nodes)

        # Count unlocked skills
        skills_result = await self.db.execute(
            select(func.count(CharacterSkillDB.skill_id))
            .where(CharacterSkillDB.character_id == character_id)
        )
        skills_count = skills_result.scalar() or 0

        # Calculate XP to next level
        xp_to_next = self.progression.xp_for_next_level(character.level) - character.total_xp
        level_progress = self.progression.level_progress(character.total_xp, character.level)

        return Character(
            id=character.id,
            user_id=character.user_id,
            name=character.name,
            level=character.level,
            total_xp=character.total_xp,
            xp_to_next_level=max(0, xp_to_next),
            level_progress=level_progress,
            stat_points=character.stat_points,
            respec_tokens=character.respec_tokens,
            stats=stats_dict,
            allocated_nodes_count=nodes_count,
            unlocked_skills_count=skills_count,
            created_at=character.created_at
        )

    async def get_character_full(self, character_id: UUID) -> Optional[CharacterFull]:
        """Get full character with detailed stats"""
        character = await self.get_by_id(character_id)
        if not character:
            return None

        # Build detailed stats
        stats_detail = {}
        stats_dict = {}
        for stat in character.stats:
            total = stat.base_value + stat.allocated_bonus
            stats_dict[stat.stat_code] = total

            # Calculate stat level from XP
            stat_level = self.progression.stat_level_from_xp(stat.stat_xp)
            xp_to_next = self.progression.stat_xp_for_next_level(stat_level) - stat.stat_xp

            stats_detail[stat.stat_code] = StatDetail(
                code=stat.stat_code,
                name=STAT_NAMES.get(stat.stat_code, stat.stat_code),
                base=stat.base_value,
                allocated=stat.allocated_bonus,
                total=total,
                xp=stat.stat_xp,
                xp_to_next=max(0, xp_to_next),
                level=stat_level
            )

        # Get allocated node codes
        node_codes = []
        for char_node in character.allocated_nodes:
            node_result = await self.db.execute(
                select(StatNodeDB.code).where(StatNodeDB.id == char_node.node_id)
            )
            code = node_result.scalar_one_or_none()
            if code:
                node_codes.append(code)

        # Get unlocked skill codes
        skill_result = await self.db.execute(
            select(SkillDB.code)
            .join(CharacterSkillDB, CharacterSkillDB.skill_id == SkillDB.id)
            .where(CharacterSkillDB.character_id == character_id)
        )
        skill_codes = [row[0] for row in skill_result.fetchall()]

        # Calculate derived stats
        derived_stats = await self.calculate_derived_stats(stats_dict)

        # Get counts
        nodes_count = len(character.allocated_nodes)
        skills_count = len(skill_codes)

        # Calculate XP to next level
        xp_to_next = self.progression.xp_for_next_level(character.level) - character.total_xp
        level_progress = self.progression.level_progress(character.total_xp, character.level)

        return CharacterFull(
            id=character.id,
            user_id=character.user_id,
            name=character.name,
            level=character.level,
            total_xp=character.total_xp,
            xp_to_next_level=max(0, xp_to_next),
            level_progress=level_progress,
            stat_points=character.stat_points,
            respec_tokens=character.respec_tokens,
            stats=stats_dict,
            allocated_nodes_count=nodes_count,
            unlocked_skills_count=skills_count,
            created_at=character.created_at,
            stats_detail=stats_detail,
            allocated_node_codes=node_codes,
            unlocked_skill_codes=skill_codes,
            derived_stats=derived_stats
        )

    async def calculate_derived_stats(self, stats: dict[str, int]) -> dict[str, float]:
        """Calculate derived stats from core stats"""
        result = await self.db.execute(
            select(DerivedStatDB).where(DerivedStatDB.is_active == True)
        )
        derived_defs = result.scalars().all()

        derived = {}
        for d in derived_defs:
            try:
                # Safe evaluation of formula
                value = self.progression.evaluate_formula(d.formula, stats)
                derived[d.code] = round(value, 2)
            except Exception:
                derived[d.code] = 0.0

        return derived

    async def update_name(self, character_id: UUID, name: str) -> Optional[Character]:
        """Update character name"""
        character = await self.get_by_id(character_id)
        if not character:
            return None

        character.name = name
        await self.db.commit()

        return await self.get_character_response(character_id)

    async def add_stat_points(self, character_id: UUID, points: int) -> bool:
        """Add stat points to character (from leveling)"""
        character = await self.get_by_id(character_id)
        if not character:
            return False

        character.stat_points += points
        await self.db.commit()
        return True

    async def get_stats(self, character_id: UUID) -> dict[str, StatDetail]:
        """Get detailed stats for a character"""
        character = await self.get_by_id(character_id)
        if not character:
            return {}

        stats_detail = {}
        for stat in character.stats:
            total = stat.base_value + stat.allocated_bonus
            stat_level = self.progression.stat_level_from_xp(stat.stat_xp)
            xp_to_next = self.progression.stat_xp_for_next_level(stat_level) - stat.stat_xp

            stats_detail[stat.stat_code] = StatDetail(
                code=stat.stat_code,
                name=STAT_NAMES.get(stat.stat_code, stat.stat_code),
                base=stat.base_value,
                allocated=stat.allocated_bonus,
                total=total,
                xp=stat.stat_xp,
                xp_to_next=max(0, xp_to_next),
                level=stat_level
            )

        return stats_detail
