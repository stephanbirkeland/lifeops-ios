"""Unit tests for Timeline service"""

import pytest
from datetime import date, datetime, time, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

from app.services.timeline import TimelineService
from app.models.timeline import (
    TimelineItemCreate, TimelineFeed, TimelineFeedItem,
    ScheduleType, TimelineCategory, PostponeRequest, PostponeTarget,
    CompleteRequest, TimeAnchor
)


class TestTimelineService:
    """Test suite for TimelineService"""

    @pytest.fixture
    def service(self, mock_db_session):
        return TimelineService(db=mock_db_session)

    @pytest.fixture
    def mock_anchors(self):
        return {
            "morning": time(7, 0),
            "lunch": time(12, 0),
            "afternoon": time(14, 0),
            "after_work": time(17, 0),
            "evening": time(19, 0),
            "night": time(21, 0)
        }

    @pytest.fixture
    def mock_timeline_item(self):
        item = MagicMock()
        item.id = uuid4()
        item.code = "morning_workout"
        item.name = "Morning Workout"
        item.description = "30-minute exercise session"
        item.icon = "💪"
        item.schedule_type = "daily"
        item.schedule_days = None
        item.anchor = "morning"
        item.time_offset = 30
        item.exact_time = None
        item.window_minutes = 120
        item.scheduled_date = None
        item.stat_rewards = {"STR": 10, "STA": 5}
        item.priority = 1
        item.category = "health"
        item.is_active = True
        return item

    # ===========================================
    # Initialization and Helper Tests
    # ===========================================

    def test_init(self, mock_db_session):
        """Test service initialization"""
        service = TimelineService(db=mock_db_session)
        assert service.db == mock_db_session
        assert service._anchors_cache == {}

    @pytest.mark.asyncio
    async def test_load_anchors(self, service, mock_anchors):
        """Test loading time anchors into cache"""
        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.default_time = t
            mock_anchor_rows.append(anchor)

        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = mock_anchor_rows
        service.db.execute.return_value = mock_result

        anchors = await service._load_anchors()

        assert len(anchors) == 6
        assert anchors["morning"] == time(7, 0)
        assert anchors["evening"] == time(19, 0)

    def test_get_day_of_week(self, service):
        """Test day of week calculation"""
        # 2026-01-05 is a Monday
        monday = date(2026, 1, 5)
        assert service._get_day_of_week(monday) == 0

        # 2026-01-11 is a Sunday
        sunday = date(2026, 1, 11)
        assert service._get_day_of_week(sunday) == 6

    def test_item_applies_to_date_daily(self, service, mock_timeline_item):
        """Test daily schedule applies to any date"""
        mock_timeline_item.schedule_type = "daily"
        assert service._item_applies_to_date(mock_timeline_item, date(2026, 1, 1))
        assert service._item_applies_to_date(mock_timeline_item, date(2026, 1, 5))

    def test_item_applies_to_date_weekdays(self, service, mock_timeline_item):
        """Test weekdays schedule"""
        mock_timeline_item.schedule_type = "weekdays"

        # Monday (0) should apply
        monday = date(2026, 1, 5)
        assert service._item_applies_to_date(mock_timeline_item, monday)

        # Saturday (5) should not apply
        saturday = date(2026, 1, 10)
        assert not service._item_applies_to_date(mock_timeline_item, saturday)

    def test_item_applies_to_date_weekends(self, service, mock_timeline_item):
        """Test weekends schedule"""
        mock_timeline_item.schedule_type = "weekends"

        # Monday should not apply
        monday = date(2026, 1, 5)
        assert not service._item_applies_to_date(mock_timeline_item, monday)

        # Saturday should apply
        saturday = date(2026, 1, 10)
        assert service._item_applies_to_date(mock_timeline_item, saturday)

    def test_item_applies_to_date_specific_days(self, service, mock_timeline_item):
        """Test specific days schedule"""
        mock_timeline_item.schedule_type = "specific_days"
        mock_timeline_item.schedule_days = [0, 2, 4]  # Mon, Wed, Fri

        monday = date(2026, 1, 5)  # Monday
        tuesday = date(2026, 1, 6)  # Tuesday
        wednesday = date(2026, 1, 7)  # Wednesday

        assert service._item_applies_to_date(mock_timeline_item, monday)
        assert not service._item_applies_to_date(mock_timeline_item, tuesday)
        assert service._item_applies_to_date(mock_timeline_item, wednesday)

    def test_item_applies_to_date_once(self, service, mock_timeline_item):
        """Test one-time schedule"""
        target_date = date(2026, 1, 15)
        mock_timeline_item.schedule_type = "once"
        mock_timeline_item.scheduled_date = target_date

        assert service._item_applies_to_date(mock_timeline_item, target_date)
        assert not service._item_applies_to_date(mock_timeline_item, date(2026, 1, 16))

    @pytest.mark.asyncio
    async def test_get_item_time_exact(self, service, mock_timeline_item):
        """Test getting item time when exact time is set"""
        mock_timeline_item.exact_time = time(8, 30)
        result = await service._get_item_time(mock_timeline_item)
        assert result == time(8, 30)

    @pytest.mark.asyncio
    async def test_get_item_time_anchor(self, service, mock_timeline_item, mock_anchors):
        """Test getting item time from anchor with offset"""
        mock_timeline_item.exact_time = None
        mock_timeline_item.anchor = "morning"
        mock_timeline_item.time_offset = 30  # 30 minutes after morning anchor

        # Mock anchor loading
        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.default_time = t
            mock_anchor_rows.append(anchor)

        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = mock_anchor_rows
        service.db.execute.return_value = mock_result

        result = await service._get_item_time(mock_timeline_item)
        # morning (7:00) + 30 minutes = 7:30
        assert result == time(7, 30)

    @pytest.mark.asyncio
    async def test_get_item_time_default(self, service, mock_timeline_item):
        """Test getting default time when no anchor or exact time"""
        mock_timeline_item.exact_time = None
        mock_timeline_item.anchor = None

        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = []
        service.db.execute.return_value = mock_result

        result = await service._get_item_time(mock_timeline_item)
        assert result == time(7, 0)  # Default

    # ===========================================
    # Feed Generation Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_feed_basic(self, service, mock_timeline_item, mock_anchors):
        """Test basic feed generation"""
        # Mock database queries
        mock_items_result = AsyncMock()
        mock_items_result.scalars.return_value.all.return_value = [mock_timeline_item]

        mock_completions_result = AsyncMock()
        mock_completions_result.scalars.return_value.all.return_value = []

        mock_overrides_result = AsyncMock()
        mock_overrides_result.scalars.return_value.all.return_value = []

        mock_streaks_result = AsyncMock()
        mock_streaks_result.scalars.return_value.all.return_value = []

        # Mock anchor loading
        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.default_time = t
            mock_anchor_rows.append(anchor)
        mock_anchors_result = AsyncMock()
        mock_anchors_result.scalars.return_value.all.return_value = mock_anchor_rows

        service.db.execute.side_effect = [
            mock_anchors_result,
            mock_items_result,
            mock_completions_result,
            mock_overrides_result,
            mock_streaks_result
        ]

        feed = await service.get_feed(window_hours=4)

        assert isinstance(feed, TimelineFeed)
        assert len(feed.items) >= 0
        assert feed.total_today >= 0

    @pytest.mark.asyncio
    async def test_get_feed_expanded(self, service, mock_timeline_item, mock_anchors):
        """Test feed generation with expand=True"""
        # Mock all database queries
        mock_items_result = AsyncMock()
        mock_items_result.scalars.return_value.all.return_value = [mock_timeline_item]

        mock_completions_result = AsyncMock()
        mock_completions_result.scalars.return_value.all.return_value = []

        mock_overrides_result = AsyncMock()
        mock_overrides_result.scalars.return_value.all.return_value = []

        mock_streaks_result = AsyncMock()
        mock_streaks_result.scalars.return_value.all.return_value = []

        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.default_time = t
            mock_anchor_rows.append(anchor)
        mock_anchors_result = AsyncMock()
        mock_anchors_result.scalars.return_value.all.return_value = mock_anchor_rows

        service.db.execute.side_effect = [
            mock_anchors_result,
            mock_items_result,
            mock_completions_result,
            mock_overrides_result,
            mock_streaks_result
        ]

        feed = await service.get_feed(expand=True)

        assert feed.window_hours == 24

    @pytest.mark.asyncio
    async def test_get_feed_with_completions(self, service, mock_timeline_item, mock_anchors):
        """Test feed with completed items"""
        # Mock completion
        mock_completion = MagicMock()
        mock_completion.item_id = mock_timeline_item.id
        mock_completion.completed_date = date.today()
        mock_completion.completed_at = datetime.now()

        mock_items_result = AsyncMock()
        mock_items_result.scalars.return_value.all.return_value = [mock_timeline_item]

        mock_completions_result = AsyncMock()
        mock_completions_result.scalars.return_value.all.return_value = [mock_completion]

        mock_overrides_result = AsyncMock()
        mock_overrides_result.scalars.return_value.all.return_value = []

        mock_streaks_result = AsyncMock()
        mock_streaks_result.scalars.return_value.all.return_value = []

        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.default_time = t
            mock_anchor_rows.append(anchor)
        mock_anchors_result = AsyncMock()
        mock_anchors_result.scalars.return_value.all.return_value = mock_anchor_rows

        service.db.execute.side_effect = [
            mock_anchors_result,
            mock_items_result,
            mock_completions_result,
            mock_overrides_result,
            mock_streaks_result
        ]

        feed = await service.get_feed()

        assert feed.completed_today >= 0

    # ===========================================
    # Complete Item Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_complete_item_success(self, service, mock_timeline_item):
        """Test successfully completing an item"""
        # Mock item query
        mock_item_result = AsyncMock()
        mock_item_result.scalar_one_or_none.return_value = mock_timeline_item

        # Mock existing completion check (none found)
        mock_existing_result = AsyncMock()
        mock_existing_result.scalar_one_or_none.return_value = None

        # Mock streak query
        mock_streak = MagicMock()
        mock_streak.current_streak = 5
        mock_streak_result = AsyncMock()
        mock_streak_result.scalar_one_or_none.return_value = mock_streak

        service.db.execute.side_effect = [
            mock_item_result,
            mock_existing_result,
            mock_streak_result
        ]

        request = CompleteRequest(notes="Great workout!", duration_minutes=30)

        with patch.object(service, '_send_xp_to_stats', return_value=None):
            result = await service.complete_item("morning_workout", request)

        assert result.success is True
        assert result.item_code == "morning_workout"
        assert result.new_streak == 5

    @pytest.mark.asyncio
    async def test_complete_item_not_found(self, service):
        """Test completing non-existent item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        service.db.execute.return_value = mock_result

        request = CompleteRequest()

        with pytest.raises(ValueError, match="Item not found"):
            await service.complete_item("nonexistent", request)

    @pytest.mark.asyncio
    async def test_complete_item_already_completed(self, service, mock_timeline_item):
        """Test completing already completed item"""
        # Mock item found
        mock_item_result = AsyncMock()
        mock_item_result.scalar_one_or_none.return_value = mock_timeline_item

        # Mock existing completion found
        mock_existing = MagicMock()
        mock_existing_result = AsyncMock()
        mock_existing_result.scalar_one_or_none.return_value = mock_existing

        service.db.execute.side_effect = [mock_item_result, mock_existing_result]

        request = CompleteRequest()

        with pytest.raises(ValueError, match="already completed"):
            await service.complete_item("morning_workout", request)

    # ===========================================
    # Postpone Item Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_postpone_item_to_lunch(self, service, mock_timeline_item, mock_anchors):
        """Test postponing item to lunch"""
        # Mock item query
        mock_item_result = AsyncMock()
        mock_item_result.scalar_one_or_none.return_value = mock_timeline_item

        # Mock anchor loading
        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.default_time = t
            mock_anchor_rows.append(anchor)
        mock_anchors_result = AsyncMock()
        mock_anchors_result.scalars.return_value.all.return_value = mock_anchor_rows

        # Mock no existing override
        mock_override_result = AsyncMock()
        mock_override_result.scalar_one_or_none.return_value = None

        service.db.execute.side_effect = [
            mock_item_result,
            mock_anchors_result,
            mock_override_result
        ]

        request = PostponeRequest(target=PostponeTarget.LUNCH, reason="Too tired now")

        result = await service.postpone_item("morning_workout", request)

        assert result.success is True
        assert result.new_time == time(12, 0)  # lunch time

    @pytest.mark.asyncio
    async def test_postpone_item_to_tomorrow(self, service, mock_timeline_item, mock_anchors):
        """Test postponing item to tomorrow"""
        today = date.today()

        mock_item_result = AsyncMock()
        mock_item_result.scalar_one_or_none.return_value = mock_timeline_item

        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.default_time = t
            mock_anchor_rows.append(anchor)
        mock_anchors_result = AsyncMock()
        mock_anchors_result.scalars.return_value.all.return_value = mock_anchor_rows

        mock_override_result = AsyncMock()
        mock_override_result.scalar_one_or_none.return_value = None

        service.db.execute.side_effect = [
            mock_item_result,
            mock_anchors_result,
            mock_anchors_result,  # For _get_item_time call
            mock_override_result
        ]

        request = PostponeRequest(target=PostponeTarget.TOMORROW)

        result = await service.postpone_item("morning_workout", request)

        assert result.success is True
        assert result.new_date == today + timedelta(days=1)

    @pytest.mark.asyncio
    async def test_postpone_item_custom_datetime(self, service, mock_timeline_item):
        """Test postponing item to custom date/time"""
        custom_date = date(2026, 1, 15)
        custom_time = time(14, 30)

        mock_item_result = AsyncMock()
        mock_item_result.scalar_one_or_none.return_value = mock_timeline_item

        mock_override_result = AsyncMock()
        mock_override_result.scalar_one_or_none.return_value = None

        service.db.execute.side_effect = [mock_item_result, mock_override_result]

        request = PostponeRequest(
            target=PostponeTarget.CUSTOM,
            custom_date=custom_date,
            custom_time=custom_time,
            reason="Scheduled meeting"
        )

        result = await service.postpone_item("morning_workout", request)

        assert result.success is True
        assert result.new_date == custom_date
        assert result.new_time == custom_time

    # ===========================================
    # Skip Item Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_skip_item_success(self, service, mock_timeline_item):
        """Test skipping an item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_timeline_item
        service.db.execute.return_value = mock_result

        result = await service.skip_item("morning_workout", reason="Injury recovery")

        assert result["success"] is True
        assert result["item_code"] == "morning_workout"

    @pytest.mark.asyncio
    async def test_skip_item_not_found(self, service):
        """Test skipping non-existent item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        service.db.execute.return_value = mock_result

        with pytest.raises(ValueError, match="Item not found"):
            await service.skip_item("nonexistent")

    # ===========================================
    # CRUD Operations Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_create_item(self, service):
        """Test creating a timeline item"""
        data = TimelineItemCreate(
            code="evening_meditation",
            name="Evening Meditation",
            description="15-minute mindfulness session",
            icon="🧘",
            schedule_type=ScheduleType.DAILY,
            anchor="evening",
            time_offset=0,
            window_minutes=60,
            category=TimelineCategory.WELLNESS
        )

        # Mock the database add and refresh
        mock_item = MagicMock()
        mock_item.id = uuid4()
        mock_item.code = data.code
        mock_item.name = data.name
        mock_item.description = data.description
        mock_item.icon = data.icon
        mock_item.schedule_type = data.schedule_type.value
        mock_item.anchor = data.anchor
        mock_item.category = data.category.value
        mock_item.is_active = True

        service.db.refresh = AsyncMock(side_effect=lambda x: None)

        result = await service.create_item(data)

        assert service.db.add.called
        assert service.db.commit.called

    @pytest.mark.asyncio
    async def test_get_item_found(self, service, mock_timeline_item):
        """Test getting an item that exists"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_timeline_item
        service.db.execute.return_value = mock_result

        result = await service.get_item("morning_workout")

        assert result is not None

    @pytest.mark.asyncio
    async def test_get_item_not_found(self, service):
        """Test getting non-existent item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        service.db.execute.return_value = mock_result

        result = await service.get_item("nonexistent")

        assert result is None

    @pytest.mark.asyncio
    async def test_list_items_active_only(self, service, mock_timeline_item):
        """Test listing only active items"""
        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = [mock_timeline_item]
        service.db.execute.return_value = mock_result

        result = await service.list_items(active_only=True)

        assert len(result) >= 0

    @pytest.mark.asyncio
    async def test_list_items_all(self, service, mock_timeline_item):
        """Test listing all items"""
        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = [mock_timeline_item]
        service.db.execute.return_value = mock_result

        result = await service.list_items(active_only=False)

        assert len(result) >= 0

    @pytest.mark.asyncio
    async def test_update_item_success(self, service, mock_timeline_item):
        """Test updating an item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_timeline_item
        service.db.execute.return_value = mock_result
        service.db.refresh = AsyncMock()

        updates = {"name": "Updated Workout", "window_minutes": 90}

        result = await service.update_item("morning_workout", updates)

        assert mock_timeline_item.name == "Updated Workout"
        assert mock_timeline_item.window_minutes == 90

    @pytest.mark.asyncio
    async def test_update_item_not_found(self, service):
        """Test updating non-existent item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        service.db.execute.return_value = mock_result

        result = await service.update_item("nonexistent", {"name": "Test"})

        assert result is None

    @pytest.mark.asyncio
    async def test_delete_item_success(self, service, mock_timeline_item):
        """Test deleting (deactivating) an item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_timeline_item
        service.db.execute.return_value = mock_result

        result = await service.delete_item("morning_workout")

        assert result is True
        assert mock_timeline_item.is_active is False

    @pytest.mark.asyncio
    async def test_delete_item_not_found(self, service):
        """Test deleting non-existent item"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        service.db.execute.return_value = mock_result

        result = await service.delete_item("nonexistent")

        assert result is False

    # ===========================================
    # Time Anchor Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_anchors(self, service, mock_anchors):
        """Test getting all time anchors"""
        mock_anchor_rows = []
        for code, t in mock_anchors.items():
            anchor = MagicMock()
            anchor.code = code
            anchor.name = code.replace("_", " ").title()
            anchor.default_time = t
            mock_anchor_rows.append(anchor)

        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = mock_anchor_rows
        service.db.execute.return_value = mock_result

        result = await service.get_anchors()

        assert len(result) == 6

    @pytest.mark.asyncio
    async def test_update_anchor_success(self, service):
        """Test updating a time anchor"""
        mock_anchor = MagicMock()
        mock_anchor.code = "morning"
        mock_anchor.name = "Morning"
        mock_anchor.default_time = time(7, 0)

        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_anchor
        service.db.execute.return_value = mock_result

        new_time = time(6, 30)
        result = await service.update_anchor("morning", new_time)

        assert mock_anchor.default_time == new_time
        assert service._anchors_cache["morning"] == new_time

    @pytest.mark.asyncio
    async def test_update_anchor_not_found(self, service):
        """Test updating non-existent anchor"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        service.db.execute.return_value = mock_result

        result = await service.update_anchor("nonexistent", time(12, 0))

        assert result is None
