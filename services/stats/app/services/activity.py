"""Activity service - XP grants and activity logging"""

from uuid import UUID
from datetime import datetime
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.activity import (
    ActivityLogDB,
    Activity, ActivityCreate, ActivityResponse, ActivityBatchResponse
)
from app.models.character import CharacterDB, CharacterStatDB
from app.services.progression import ProgressionService
from app.core.config import settings


class ActivityService:
    """Service for activity logging and XP grants"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.progression = ProgressionService()

    async def log_activity(self, data: ActivityCreate) -> ActivityResponse:
        """Log an activity and grant XP"""
        # Get character by user_id
        result = await self.db.execute(
            select(CharacterDB).where(CharacterDB.user_id == data.user_id)
        )
        character = result.scalar_one_or_none()
        if not character:
            raise ValueError(f"No character found for user {data.user_id}")

        # Calculate XP grants
        if data.custom_xp:
            xp_grants = data.custom_xp
        else:
            xp_grants = self._calculate_xp(data.activity_type, data.activity_data)

        # Create activity log
        activity = ActivityLogDB(
            character_id=character.id,
            activity_type=data.activity_type,
            activity_data=data.activity_data,
            source=data.source,
            source_ref=data.source_ref,
            xp_grants=xp_grants,
            activity_time=data.activity_time
        )
        self.db.add(activity)

        # Apply XP grants
        stat_level_ups = []
        total_xp_gained = 0

        for stat_code, xp in xp_grants.items():
            if xp <= 0:
                continue

            total_xp_gained += xp

            # Get or create stat
            result = await self.db.execute(
                select(CharacterStatDB)
                .where(CharacterStatDB.character_id == character.id)
                .where(CharacterStatDB.stat_code == stat_code)
            )
            stat = result.scalar_one_or_none()

            if stat:
                old_xp = stat.stat_xp
                stat.stat_xp += xp

                # Check for stat level up
                old_level, new_level, leveled = self.progression.calculate_stat_level_ups(
                    stat_code, old_xp, stat.stat_xp
                )
                if leveled:
                    stat.base_value = new_level
                    stat_level_ups.append(stat_code)

        # Add to total character XP
        old_total_xp = character.total_xp
        character.total_xp += total_xp_gained

        # Check for character level up
        old_level, new_level, stat_points = self.progression.calculate_level_ups(
            old_total_xp, character.total_xp
        )
        character_level_up = new_level > old_level
        if character_level_up:
            character.level = new_level
            character.stat_points += stat_points

        await self.db.commit()
        await self.db.refresh(activity)

        # Build message
        if character_level_up:
            message = f"Level up! You are now level {new_level}. Gained {stat_points} stat points!"
        elif stat_level_ups:
            message = f"Stats improved: {', '.join(stat_level_ups)}"
        else:
            message = f"Gained XP: {', '.join(f'{k}+{v}' for k, v in xp_grants.items() if v > 0)}"

        return ActivityResponse(
            success=True,
            activity_id=activity.id,
            xp_granted=xp_grants,
            stat_level_ups=stat_level_ups,
            character_level_up=character_level_up,
            new_level=new_level if character_level_up else None,
            message=message
        )

    async def log_batch(
        self, activities: list[ActivityCreate]
    ) -> ActivityBatchResponse:
        """Log multiple activities at once"""
        total_xp: dict[str, int] = {}
        all_stat_level_ups = set()
        character_level_up = False
        processed = 0

        for activity in activities:
            try:
                response = await self.log_activity(activity)
                processed += 1

                # Accumulate XP
                for stat, xp in response.xp_granted.items():
                    total_xp[stat] = total_xp.get(stat, 0) + xp

                # Collect level ups
                all_stat_level_ups.update(response.stat_level_ups)
                if response.character_level_up:
                    character_level_up = True

            except Exception:
                continue

        return ActivityBatchResponse(
            success=processed > 0,
            processed=processed,
            total_xp=total_xp,
            stat_level_ups=list(all_stat_level_ups),
            character_level_up=character_level_up
        )

    def _calculate_xp(
        self, activity_type: str, activity_data: dict
    ) -> dict[str, int]:
        """Calculate XP grants based on activity type and data"""
        # Get base XP from mapping
        base_xp = settings.ACTIVITY_XP_MAPPING.get(activity_type, {})

        if not base_xp:
            # Unknown activity - minimal XP
            return {"LCK": 5}

        # Copy base values
        xp = dict(base_xp)

        # Apply modifiers from activity_data
        multiplier = activity_data.get("multiplier", 1.0)
        duration = activity_data.get("duration_minutes", 0)
        intensity = activity_data.get("intensity", "normal")
        quality = activity_data.get("quality", 1.0)

        # Duration bonus (for time-based activities)
        if duration > 0:
            duration_mult = min(duration / 60, 2.0)  # Cap at 2x for 60+ minutes
            for stat in xp:
                xp[stat] = int(xp[stat] * duration_mult)

        # Intensity modifier
        intensity_mults = {
            "low": 0.7,
            "normal": 1.0,
            "high": 1.3,
            "extreme": 1.5
        }
        int_mult = intensity_mults.get(intensity, 1.0)
        for stat in xp:
            xp[stat] = int(xp[stat] * int_mult)

        # Quality modifier
        for stat in xp:
            xp[stat] = int(xp[stat] * quality)

        # Global multiplier
        for stat in xp:
            xp[stat] = int(xp[stat] * multiplier)

        return xp

    async def get_activity(self, activity_id: UUID) -> Optional[Activity]:
        """Get a single activity by ID"""
        result = await self.db.execute(
            select(ActivityLogDB).where(ActivityLogDB.id == activity_id)
        )
        activity = result.scalar_one_or_none()
        if not activity:
            return None

        return Activity(
            id=activity.id,
            character_id=activity.character_id,
            activity_type=activity.activity_type,
            activity_data=activity.activity_data,
            source=activity.source,
            source_ref=activity.source_ref,
            xp_grants=activity.xp_grants,
            activity_time=activity.activity_time,
            logged_at=activity.logged_at
        )

    async def get_recent_activities(
        self,
        character_id: UUID,
        limit: int = 20,
        offset: int = 0
    ) -> list[Activity]:
        """Get recent activities for a character"""
        result = await self.db.execute(
            select(ActivityLogDB)
            .where(ActivityLogDB.character_id == character_id)
            .order_by(ActivityLogDB.activity_time.desc())
            .offset(offset)
            .limit(limit)
        )
        activities = result.scalars().all()

        return [
            Activity(
                id=a.id,
                character_id=a.character_id,
                activity_type=a.activity_type,
                activity_data=a.activity_data,
                source=a.source,
                source_ref=a.source_ref,
                xp_grants=a.xp_grants,
                activity_time=a.activity_time,
                logged_at=a.logged_at
            )
            for a in activities
        ]

    async def get_activities_by_date_range(
        self,
        character_id: UUID,
        start_date: datetime,
        end_date: datetime
    ) -> list[Activity]:
        """Get activities within a date range"""
        result = await self.db.execute(
            select(ActivityLogDB)
            .where(ActivityLogDB.character_id == character_id)
            .where(ActivityLogDB.activity_time >= start_date)
            .where(ActivityLogDB.activity_time <= end_date)
            .order_by(ActivityLogDB.activity_time.desc())
        )
        activities = result.scalars().all()

        return [
            Activity(
                id=a.id,
                character_id=a.character_id,
                activity_type=a.activity_type,
                activity_data=a.activity_data,
                source=a.source,
                source_ref=a.source_ref,
                xp_grants=a.xp_grants,
                activity_time=a.activity_time,
                logged_at=a.logged_at
            )
            for a in activities
        ]
