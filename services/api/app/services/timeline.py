"""Timeline service - rolling task/event feed with smart scheduling"""

from datetime import datetime, date, time, timedelta
from typing import Optional
from uuid import UUID
import httpx

from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.timeline import (
    TimeAnchorDB, TimelineItemDB, TimelineOverrideDB,
    TimelineCompletionDB, TimelineStreakDB, CalendarEventDB,
    TimeAnchor, TimelineItem, TimelineItemCreate,
    TimelineFeedItem, TimelineFeed,
    PostponeRequest, PostponeResponse, PostponeTarget,
    CompleteRequest, CompleteResponse
)


class TimelineService:
    """Service for timeline operations"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self._anchors_cache: dict[str, time] = {}

    async def _load_anchors(self) -> dict[str, time]:
        """Load time anchors into cache"""
        if not self._anchors_cache:
            result = await self.db.execute(select(TimeAnchorDB))
            for anchor in result.scalars().all():
                self._anchors_cache[anchor.code] = anchor.default_time
        return self._anchors_cache

    def _get_day_of_week(self, d: date) -> int:
        """Get day of week (0=Monday, 6=Sunday)"""
        return d.weekday()

    def _item_applies_to_date(self, item: TimelineItemDB, check_date: date) -> bool:
        """Check if item should appear on a given date"""
        dow = self._get_day_of_week(check_date)

        if item.schedule_type == "daily":
            return True
        elif item.schedule_type == "weekdays":
            return dow < 5
        elif item.schedule_type == "weekends":
            return dow >= 5
        elif item.schedule_type in ("weekly", "specific_days"):
            return dow in (item.schedule_days or [])
        elif item.schedule_type == "once":
            return item.scheduled_date == check_date
        return True

    async def _get_item_time(self, item: TimelineItemDB) -> time:
        """Get the effective time for an item"""
        if item.exact_time:
            return item.exact_time

        anchors = await self._load_anchors()
        if item.anchor and item.anchor in anchors:
            anchor_time = anchors[item.anchor]
            # Add offset
            dt = datetime.combine(date.today(), anchor_time)
            dt += timedelta(minutes=item.time_offset or 0)
            return dt.time()

        return time(7, 0)  # Default to 7 AM

    async def get_feed(
        self,
        window_hours: int = 4,
        for_date: Optional[date] = None,
        expand: bool = False
    ) -> TimelineFeed:
        """Get the rolling timeline feed"""
        now = datetime.now()
        target_date = for_date or now.date()
        current_time = now.time() if for_date is None else time(0, 0)

        # Calculate window
        if expand:
            window_start = time(0, 0)
            window_end = time(23, 59, 59)
        else:
            window_start = current_time
            window_dt = datetime.combine(target_date, current_time) + timedelta(hours=window_hours)
            window_end = window_dt.time() if window_dt.date() == target_date else time(23, 59, 59)

        # Get active items
        result = await self.db.execute(
            select(TimelineItemDB).where(TimelineItemDB.is_active == True)
        )
        all_items = result.scalars().all()

        # Get completions for today
        result = await self.db.execute(
            select(TimelineCompletionDB).where(
                TimelineCompletionDB.completed_date == target_date
            )
        )
        completions = {c.item_id: c for c in result.scalars().all()}

        # Get overrides for today
        result = await self.db.execute(
            select(TimelineOverrideDB).where(
                or_(
                    TimelineOverrideDB.original_date == target_date,
                    TimelineOverrideDB.new_date == target_date
                )
            )
        )
        overrides = {}
        postponed_to_today = {}
        for o in result.scalars().all():
            if o.original_date == target_date:
                overrides[o.item_id] = o
            if o.new_date == target_date:
                postponed_to_today[o.item_id] = o

        # Get streaks
        result = await self.db.execute(select(TimelineStreakDB))
        streaks = {s.item_id: s for s in result.scalars().all()}

        # Build feed items
        feed_items: list[TimelineFeedItem] = []
        hidden_items: list[TimelineFeedItem] = []
        total_today = 0
        completed_today = 0

        for item in all_items:
            # Check if item applies to this date
            if not self._item_applies_to_date(item, target_date):
                # Check if postponed to today
                if item.id not in postponed_to_today:
                    continue

            # Check for overrides (skip or postpone away from today)
            if item.id in overrides:
                override = overrides[item.id]
                if override.override_type == "skip":
                    continue
                if override.override_type == "postpone" and override.new_date != target_date:
                    continue

            total_today += 1

            # Get scheduled time
            if item.id in postponed_to_today:
                # Use postponed time
                override = postponed_to_today[item.id]
                if override.new_time:
                    scheduled_time = override.new_time
                elif override.new_anchor:
                    anchors = await self._load_anchors()
                    scheduled_time = anchors.get(override.new_anchor, time(12, 0))
                else:
                    scheduled_time = await self._get_item_time(item)
            else:
                scheduled_time = await self._get_item_time(item)

            # Calculate window end
            window_end_dt = datetime.combine(target_date, scheduled_time) + timedelta(minutes=item.window_minutes or 60)
            item_window_end = window_end_dt.time()

            # Determine status
            is_completed = item.id in completions
            if is_completed:
                status = "completed"
                completed_today += 1
            elif current_time > item_window_end:
                status = "overdue"
            elif current_time >= scheduled_time:
                status = "active"
            else:
                status = "upcoming"

            # Get streak
            streak = streaks.get(item.id)
            current_streak = streak.current_streak if streak else 0
            best_streak = streak.best_streak if streak else 0

            feed_item = TimelineFeedItem(
                id=item.id,
                code=item.code,
                name=item.name,
                description=item.description,
                icon=item.icon,
                category=item.category,
                scheduled_time=scheduled_time,
                window_end=item_window_end,
                status=status,
                current_streak=current_streak,
                best_streak=best_streak,
                completed_at=completions[item.id].completed_at if is_completed else None,
                stat_rewards=item.stat_rewards or {}
            )

            # Check if in window
            if expand or (scheduled_time <= window_end and item_window_end >= window_start):
                feed_items.append(feed_item)
            else:
                hidden_items.append(feed_item)

        # Sort by scheduled time, then priority
        feed_items.sort(key=lambda x: (x.scheduled_time, -len(x.status)))  # active/overdue first

        # Find next hidden item
        next_hidden_at = None
        if hidden_items:
            hidden_items.sort(key=lambda x: x.scheduled_time)
            next_hidden_at = hidden_items[0].scheduled_time

        completion_rate = (completed_today / total_today * 100) if total_today > 0 else 0

        return TimelineFeed(
            now=now,
            date=target_date,
            window_hours=window_hours if not expand else 24,
            items=feed_items,
            completed_today=completed_today,
            total_today=total_today,
            completion_rate=round(completion_rate, 1),
            hidden_count=len(hidden_items),
            next_hidden_at=next_hidden_at
        )

    async def complete_item(
        self,
        item_code: str,
        request: CompleteRequest,
        for_date: Optional[date] = None
    ) -> CompleteResponse:
        """Mark an item as completed"""
        target_date = for_date or date.today()

        # Get item
        result = await self.db.execute(
            select(TimelineItemDB).where(TimelineItemDB.code == item_code)
        )
        item = result.scalar_one_or_none()
        if not item:
            raise ValueError(f"Item not found: {item_code}")

        # Check if already completed
        result = await self.db.execute(
            select(TimelineCompletionDB).where(
                and_(
                    TimelineCompletionDB.item_id == item.id,
                    TimelineCompletionDB.completed_date == target_date
                )
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            raise ValueError(f"Item already completed today: {item_code}")

        # Create completion
        completion = TimelineCompletionDB(
            item_id=item.id,
            completed_date=target_date,
            notes=request.notes,
            duration_minutes=request.duration_minutes,
            xp_granted=item.stat_rewards or {}
        )
        self.db.add(completion)
        await self.db.commit()

        # Get updated streak
        result = await self.db.execute(
            select(TimelineStreakDB).where(TimelineStreakDB.item_id == item.id)
        )
        streak = result.scalar_one_or_none()
        new_streak = streak.current_streak if streak else 1

        # Send XP to Stats Service (fire and forget)
        if item.stat_rewards:
            await self._send_xp_to_stats(item.stat_rewards, item_code)

        return CompleteResponse(
            success=True,
            item_code=item_code,
            completed_at=datetime.now(),
            xp_granted=item.stat_rewards or {},
            new_streak=new_streak,
            message=f"Completed {item.name}! Streak: {new_streak} days"
        )

    async def postpone_item(
        self,
        item_code: str,
        request: PostponeRequest,
        for_date: Optional[date] = None
    ) -> PostponeResponse:
        """Postpone an item to a later time"""
        target_date = for_date or date.today()

        # Get item
        result = await self.db.execute(
            select(TimelineItemDB).where(TimelineItemDB.code == item_code)
        )
        item = result.scalar_one_or_none()
        if not item:
            raise ValueError(f"Item not found: {item_code}")

        # Calculate new date/time based on target
        anchors = await self._load_anchors()
        new_date = target_date
        new_time = None
        new_anchor = None

        if request.target == PostponeTarget.CUSTOM:
            if request.custom_date:
                new_date = request.custom_date
            if request.custom_time:
                new_time = request.custom_time
        elif request.target == PostponeTarget.LUNCH:
            new_anchor = "lunch"
            new_time = anchors.get("lunch", time(12, 0))
        elif request.target == PostponeTarget.AFTERNOON:
            new_anchor = "afternoon"
            new_time = anchors.get("afternoon", time(14, 0))
        elif request.target == PostponeTarget.AFTER_WORK:
            new_anchor = "after_work"
            new_time = anchors.get("after_work", time(17, 0))
        elif request.target == PostponeTarget.EVENING:
            new_anchor = "evening"
            new_time = anchors.get("evening", time(19, 0))
        elif request.target == PostponeTarget.TONIGHT:
            new_anchor = "night"
            new_time = anchors.get("night", time(21, 0))
        elif request.target == PostponeTarget.TOMORROW:
            new_date = target_date + timedelta(days=1)
            new_time = await self._get_item_time(item)
        elif request.target == PostponeTarget.TOMORROW_MORNING:
            new_date = target_date + timedelta(days=1)
            new_anchor = "morning"
            new_time = anchors.get("morning", time(7, 0))
        elif request.target == PostponeTarget.NEXT_WEEK:
            new_date = target_date + timedelta(days=7)
            new_time = await self._get_item_time(item)

        # Create or update override
        result = await self.db.execute(
            select(TimelineOverrideDB).where(
                and_(
                    TimelineOverrideDB.item_id == item.id,
                    TimelineOverrideDB.original_date == target_date
                )
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            existing.override_type = "postpone"
            existing.new_date = new_date
            existing.new_time = new_time
            existing.new_anchor = new_anchor
            existing.reason = request.reason
        else:
            override = TimelineOverrideDB(
                item_id=item.id,
                original_date=target_date,
                override_type="postpone",
                new_date=new_date,
                new_time=new_time,
                new_anchor=new_anchor,
                reason=request.reason
            )
            self.db.add(override)

        await self.db.commit()

        return PostponeResponse(
            success=True,
            item_code=item_code,
            original_date=target_date,
            new_date=new_date,
            new_time=new_time or await self._get_item_time(item),
            message=f"Postponed {item.name} to {new_date} at {new_time or 'original time'}"
        )

    async def skip_item(
        self,
        item_code: str,
        reason: Optional[str] = None,
        for_date: Optional[date] = None
    ) -> dict:
        """Skip an item for today"""
        target_date = for_date or date.today()

        # Get item
        result = await self.db.execute(
            select(TimelineItemDB).where(TimelineItemDB.code == item_code)
        )
        item = result.scalar_one_or_none()
        if not item:
            raise ValueError(f"Item not found: {item_code}")

        # Create skip override
        override = TimelineOverrideDB(
            item_id=item.id,
            original_date=target_date,
            override_type="skip",
            reason=reason
        )
        self.db.add(override)
        await self.db.commit()

        return {
            "success": True,
            "item_code": item_code,
            "skipped_date": target_date,
            "message": f"Skipped {item.name} for {target_date}"
        }

    async def create_item(self, data: TimelineItemCreate) -> TimelineItem:
        """Create a new timeline item"""
        item = TimelineItemDB(
            code=data.code,
            name=data.name,
            description=data.description,
            icon=data.icon,
            schedule_type=data.schedule_type.value,
            schedule_days=data.schedule_days,
            anchor=data.anchor,
            time_offset=data.time_offset,
            exact_time=data.exact_time,
            window_minutes=data.window_minutes,
            scheduled_date=data.scheduled_date,
            stat_rewards=data.stat_rewards,
            priority=data.priority,
            category=data.category.value
        )
        self.db.add(item)
        await self.db.commit()
        await self.db.refresh(item)

        return TimelineItem.model_validate(item)

    async def get_item(self, item_code: str) -> Optional[TimelineItem]:
        """Get a timeline item by code"""
        result = await self.db.execute(
            select(TimelineItemDB).where(TimelineItemDB.code == item_code)
        )
        item = result.scalar_one_or_none()
        if not item:
            return None
        return TimelineItem.model_validate(item)

    async def list_items(self, active_only: bool = True) -> list[TimelineItem]:
        """List all timeline items"""
        query = select(TimelineItemDB)
        if active_only:
            query = query.where(TimelineItemDB.is_active == True)

        result = await self.db.execute(query)
        return [TimelineItem.model_validate(item) for item in result.scalars().all()]

    async def update_item(
        self,
        item_code: str,
        updates: dict
    ) -> Optional[TimelineItem]:
        """Update a timeline item"""
        result = await self.db.execute(
            select(TimelineItemDB).where(TimelineItemDB.code == item_code)
        )
        item = result.scalar_one_or_none()
        if not item:
            return None

        for key, value in updates.items():
            if hasattr(item, key):
                setattr(item, key, value)

        await self.db.commit()
        await self.db.refresh(item)

        return TimelineItem.model_validate(item)

    async def delete_item(self, item_code: str) -> bool:
        """Delete (deactivate) a timeline item"""
        result = await self.db.execute(
            select(TimelineItemDB).where(TimelineItemDB.code == item_code)
        )
        item = result.scalar_one_or_none()
        if not item:
            return False

        item.is_active = False
        await self.db.commit()
        return True

    async def get_anchors(self) -> list[TimeAnchor]:
        """Get all time anchors"""
        result = await self.db.execute(select(TimeAnchorDB))
        return [TimeAnchor.model_validate(a) for a in result.scalars().all()]

    async def update_anchor(self, code: str, new_time: time) -> Optional[TimeAnchor]:
        """Update a time anchor"""
        result = await self.db.execute(
            select(TimeAnchorDB).where(TimeAnchorDB.code == code)
        )
        anchor = result.scalar_one_or_none()
        if not anchor:
            return None

        anchor.default_time = new_time
        self._anchors_cache[code] = new_time
        await self.db.commit()

        return TimeAnchor.model_validate(anchor)

    async def _send_xp_to_stats(self, xp_grants: dict, activity_type: str):
        """Send XP to Stats Service"""
        stats_url = getattr(settings, 'stats_service_url', None)
        if not stats_url:
            return

        try:
            async with httpx.AsyncClient() as client:
                await client.post(
                    f"{stats_url}/activities",
                    json={
                        "user_id": str(settings.default_user_id) if hasattr(settings, 'default_user_id') else None,
                        "activity_type": f"timeline_{activity_type}",
                        "activity_data": {},
                        "source": "lifeops",
                        "activity_time": datetime.now().isoformat(),
                        "custom_xp": xp_grants
                    },
                    timeout=5.0
                )
        except Exception:
            pass  # Fire and forget
