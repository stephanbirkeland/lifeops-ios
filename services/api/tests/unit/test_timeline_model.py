"""Unit tests for Timeline models"""

import pytest
from datetime import datetime, date, time
from uuid import uuid4

from app.models.timeline import (
    ScheduleType,
    OverrideType,
    ItemCategory,
    PostponeTarget,
    TimeAnchor,
    TimelineItemCreate,
    TimelineItem,
    TimelineFeedItem,
    TimelineFeed,
    PostponeRequest,
    PostponeResponse,
    CompleteRequest,
    CompleteResponse,
    CalendarEvent,
)


class TestEnums:
    """Test timeline enums"""

    def test_schedule_type_values(self):
        """Test ScheduleType enum values"""
        assert ScheduleType.DAILY == "daily"
        assert ScheduleType.WEEKDAYS == "weekdays"
        assert ScheduleType.WEEKENDS == "weekends"
        assert ScheduleType.WEEKLY == "weekly"
        assert ScheduleType.SPECIFIC_DAYS == "specific_days"
        assert ScheduleType.ONCE == "once"

    def test_override_type_values(self):
        """Test OverrideType enum values"""
        assert OverrideType.POSTPONE == "postpone"
        assert OverrideType.SKIP == "skip"
        assert OverrideType.RESCHEDULE == "reschedule"

    def test_item_category_values(self):
        """Test ItemCategory enum values"""
        assert ItemCategory.TASK == "task"
        assert ItemCategory.CHORE == "chore"
        assert ItemCategory.HABIT == "habit"
        assert ItemCategory.REMINDER == "reminder"
        assert ItemCategory.EVENT == "event"

    def test_postpone_target_values(self):
        """Test PostponeTarget enum values"""
        assert PostponeTarget.LUNCH == "lunch"
        assert PostponeTarget.AFTERNOON == "afternoon"
        assert PostponeTarget.AFTER_WORK == "after_work"
        assert PostponeTarget.EVENING == "evening"
        assert PostponeTarget.TONIGHT == "tonight"
        assert PostponeTarget.TOMORROW == "tomorrow"
        assert PostponeTarget.TOMORROW_MORNING == "tomorrow_morning"
        assert PostponeTarget.NEXT_WEEK == "next_week"
        assert PostponeTarget.CUSTOM == "custom"


class TestTimeAnchor:
    """Test TimeAnchor Pydantic model"""

    def test_time_anchor_creation(self):
        """Test TimeAnchor with all fields"""
        anchor = TimeAnchor(
            code="lunch",
            name="Lunch Time",
            default_time=time(12, 0),
            description="Default lunch time",
        )

        assert anchor.code == "lunch"
        assert anchor.name == "Lunch Time"
        assert anchor.default_time == time(12, 0)
        assert anchor.description == "Default lunch time"

    def test_time_anchor_without_description(self):
        """Test TimeAnchor without optional description"""
        anchor = TimeAnchor(
            code="morning",
            name="Morning",
            default_time=time(6, 0),
        )

        assert anchor.description is None


class TestTimelineItemCreate:
    """Test TimelineItemCreate Pydantic model"""

    def test_timeline_item_create_minimal(self):
        """Test TimelineItemCreate with minimal required fields"""
        item = TimelineItemCreate(
            code="morning_workout",
            name="Morning Workout",
        )

        assert item.code == "morning_workout"
        assert item.name == "Morning Workout"
        assert item.schedule_type == ScheduleType.DAILY
        assert item.schedule_days == []
        assert item.window_minutes == 60
        assert item.priority == 5
        assert item.category == ItemCategory.TASK

    def test_timeline_item_create_daily_with_anchor(self):
        """Test daily item with time anchor"""
        item = TimelineItemCreate(
            code="morning_workout",
            name="Morning Workout",
            schedule_type=ScheduleType.DAILY,
            anchor="morning",
            time_offset=30,  # 30 minutes after morning anchor
            category=ItemCategory.HABIT,
        )

        assert item.schedule_type == ScheduleType.DAILY
        assert item.anchor == "morning"
        assert item.time_offset == 30
        assert item.category == ItemCategory.HABIT

    def test_timeline_item_create_with_exact_time(self):
        """Test item with exact time"""
        item = TimelineItemCreate(
            code="team_meeting",
            name="Daily Team Meeting",
            exact_time=time(9, 0),
            window_minutes=15,
            category=ItemCategory.EVENT,
        )

        assert item.exact_time == time(9, 0)
        assert item.window_minutes == 15
        assert item.category == ItemCategory.EVENT

    def test_timeline_item_create_weekdays(self):
        """Test weekdays schedule"""
        item = TimelineItemCreate(
            code="work_checkin",
            name="Work Check-in",
            schedule_type=ScheduleType.WEEKDAYS,
            exact_time=time(9, 0),
        )

        assert item.schedule_type == ScheduleType.WEEKDAYS

    def test_timeline_item_create_specific_days(self):
        """Test specific days schedule"""
        item = TimelineItemCreate(
            code="gym_session",
            name="Gym Session",
            schedule_type=ScheduleType.SPECIFIC_DAYS,
            schedule_days=[0, 2, 4],  # Mon, Wed, Fri
            exact_time=time(17, 30),
        )

        assert item.schedule_type == ScheduleType.SPECIFIC_DAYS
        assert item.schedule_days == [0, 2, 4]

    def test_timeline_item_create_once(self):
        """Test one-time item"""
        future_date = date(2026, 6, 1)
        item = TimelineItemCreate(
            code="dentist_appt",
            name="Dentist Appointment",
            schedule_type=ScheduleType.ONCE,
            scheduled_date=future_date,
            exact_time=time(14, 0),
            category=ItemCategory.EVENT,
        )

        assert item.schedule_type == ScheduleType.ONCE
        assert item.scheduled_date == future_date

    def test_timeline_item_create_with_stat_rewards(self):
        """Test item with stat rewards"""
        item = TimelineItemCreate(
            code="meditation",
            name="Daily Meditation",
            stat_rewards={"WIS": 2, "STA": 1},
            category=ItemCategory.HABIT,
        )

        assert item.stat_rewards == {"WIS": 2, "STA": 1}

    def test_timeline_item_create_priority_levels(self):
        """Test different priority levels"""
        low_priority = TimelineItemCreate(
            code="optional_task",
            name="Optional Task",
            priority=1,
        )
        high_priority = TimelineItemCreate(
            code="critical_task",
            name="Critical Task",
            priority=10,
        )

        assert low_priority.priority == 1
        assert high_priority.priority == 10


class TestTimelineItem:
    """Test TimelineItem Pydantic model"""

    def test_timeline_item_full(self):
        """Test TimelineItem with all fields"""
        item_id = uuid4()
        now = datetime.utcnow()
        item = TimelineItem(
            id=item_id,
            code="morning_workout",
            name="Morning Workout",
            description="30 min cardio",
            icon="🏃",
            schedule_type="daily",
            schedule_days=[],
            anchor="morning",
            time_offset=30,
            exact_time=None,
            window_minutes=60,
            scheduled_date=None,
            stat_rewards={"STR": 3, "STA": 2},
            priority=8,
            category="habit",
            is_active=True,
            created_at=now,
        )

        assert item.id == item_id
        assert item.code == "morning_workout"
        assert item.icon == "🏃"
        assert item.stat_rewards == {"STR": 3, "STA": 2}
        assert item.is_active is True


class TestTimelineFeedItem:
    """Test TimelineFeedItem Pydantic model"""

    def test_timeline_feed_item_upcoming(self):
        """Test upcoming timeline feed item"""
        item_id = uuid4()
        item = TimelineFeedItem(
            id=item_id,
            code="morning_workout",
            name="Morning Workout",
            category="habit",
            scheduled_time=time(6, 30),
            window_end=time(7, 30),
            status="upcoming",
            current_streak=15,
            best_streak=20,
        )

        assert item.status == "upcoming"
        assert item.scheduled_time == time(6, 30)
        assert item.window_end == time(7, 30)
        assert item.current_streak == 15
        assert item.completed_at is None

    def test_timeline_feed_item_completed(self):
        """Test completed timeline feed item"""
        item_id = uuid4()
        completed_time = datetime.utcnow()
        item = TimelineFeedItem(
            id=item_id,
            code="meditation",
            name="Morning Meditation",
            category="habit",
            scheduled_time=time(6, 0),
            window_end=time(7, 0),
            status="completed",
            completed_at=completed_time,
            stat_rewards={"WIS": 2},
        )

        assert item.status == "completed"
        assert item.completed_at == completed_time
        assert item.stat_rewards == {"WIS": 2}

    def test_timeline_feed_item_overdue(self):
        """Test overdue timeline feed item"""
        item_id = uuid4()
        item = TimelineFeedItem(
            id=item_id,
            code="morning_task",
            name="Morning Task",
            category="task",
            scheduled_time=time(8, 0),
            window_end=time(9, 0),
            status="overdue",
        )

        assert item.status == "overdue"

    def test_timeline_feed_item_active(self):
        """Test active (in window) timeline feed item"""
        item_id = uuid4()
        item = TimelineFeedItem(
            id=item_id,
            code="current_task",
            name="Current Task",
            category="task",
            scheduled_time=time(10, 0),
            window_end=time(11, 0),
            status="active",
        )

        assert item.status == "active"


class TestTimelineFeed:
    """Test TimelineFeed Pydantic model"""

    def test_timeline_feed_empty(self):
        """Test empty timeline feed"""
        now = datetime.utcnow()
        today = date.today()
        feed = TimelineFeed(
            now=now,
            date=today,
            window_hours=12,
            items=[],
            completed_today=0,
            total_today=0,
            completion_rate=0.0,
            hidden_count=0,
        )

        assert feed.date == today
        assert feed.window_hours == 12
        assert len(feed.items) == 0
        assert feed.completion_rate == 0.0

    def test_timeline_feed_with_items(self):
        """Test timeline feed with multiple items"""
        now = datetime.utcnow()
        today = date.today()

        items = [
            TimelineFeedItem(
                id=uuid4(),
                code="task1",
                name="Task 1",
                category="task",
                scheduled_time=time(8, 0),
                window_end=time(9, 0),
                status="completed",
                completed_at=now,
            ),
            TimelineFeedItem(
                id=uuid4(),
                code="task2",
                name="Task 2",
                category="task",
                scheduled_time=time(10, 0),
                window_end=time(11, 0),
                status="active",
            ),
            TimelineFeedItem(
                id=uuid4(),
                code="task3",
                name="Task 3",
                category="task",
                scheduled_time=time(14, 0),
                window_end=time(15, 0),
                status="upcoming",
            ),
        ]

        feed = TimelineFeed(
            now=now,
            date=today,
            window_hours=12,
            items=items,
            completed_today=1,
            total_today=3,
            completion_rate=33.33,
            hidden_count=2,
            next_hidden_at=time(16, 0),
        )

        assert len(feed.items) == 3
        assert feed.completed_today == 1
        assert feed.total_today == 3
        assert feed.completion_rate == 33.33
        assert feed.hidden_count == 2
        assert feed.next_hidden_at == time(16, 0)

    def test_timeline_feed_completion_rate(self):
        """Test completion rate calculation"""
        now = datetime.utcnow()
        today = date.today()

        # 100% completion
        feed_100 = TimelineFeed(
            now=now,
            date=today,
            window_hours=12,
            items=[],
            completed_today=5,
            total_today=5,
            completion_rate=100.0,
            hidden_count=0,
        )
        assert feed_100.completion_rate == 100.0

        # 0% completion
        feed_0 = TimelineFeed(
            now=now,
            date=today,
            window_hours=12,
            items=[],
            completed_today=0,
            total_today=5,
            completion_rate=0.0,
            hidden_count=0,
        )
        assert feed_0.completion_rate == 0.0


class TestPostponeRequest:
    """Test PostponeRequest Pydantic model"""

    def test_postpone_request_predefined_target(self):
        """Test postpone to predefined target"""
        request = PostponeRequest(
            target=PostponeTarget.LUNCH,
            reason="Too busy this morning",
        )

        assert request.target == PostponeTarget.LUNCH
        assert request.custom_date is None
        assert request.custom_time is None
        assert request.reason == "Too busy this morning"

    def test_postpone_request_custom(self):
        """Test postpone to custom date/time"""
        custom_date = date(2026, 6, 15)
        custom_time = time(14, 30)
        request = PostponeRequest(
            target=PostponeTarget.CUSTOM,
            custom_date=custom_date,
            custom_time=custom_time,
        )

        assert request.target == PostponeTarget.CUSTOM
        assert request.custom_date == custom_date
        assert request.custom_time == custom_time

    def test_postpone_request_tomorrow(self):
        """Test postpone to tomorrow"""
        request = PostponeRequest(
            target=PostponeTarget.TOMORROW,
        )

        assert request.target == PostponeTarget.TOMORROW
        assert request.reason is None


class TestPostponeResponse:
    """Test PostponeResponse Pydantic model"""

    def test_postpone_response(self):
        """Test postpone response"""
        original = date.today()
        new = date(2026, 6, 15)
        response = PostponeResponse(
            success=True,
            item_code="morning_workout",
            original_date=original,
            new_date=new,
            new_time=time(14, 0),
            message="Task postponed to June 15 at 2:00 PM",
        )

        assert response.success is True
        assert response.item_code == "morning_workout"
        assert response.original_date == original
        assert response.new_date == new
        assert response.new_time == time(14, 0)


class TestCompleteRequest:
    """Test CompleteRequest Pydantic model"""

    def test_complete_request_minimal(self):
        """Test complete request with no optional fields"""
        request = CompleteRequest()

        assert request.notes is None
        assert request.duration_minutes is None

    def test_complete_request_with_details(self):
        """Test complete request with notes and duration"""
        request = CompleteRequest(
            notes="Great workout! Felt strong today.",
            duration_minutes=45,
        )

        assert request.notes == "Great workout! Felt strong today."
        assert request.duration_minutes == 45


class TestCompleteResponse:
    """Test CompleteResponse Pydantic model"""

    def test_complete_response(self):
        """Test complete response"""
        completed_time = datetime.utcnow()
        response = CompleteResponse(
            success=True,
            item_code="morning_workout",
            completed_at=completed_time,
            xp_granted={"STR": 3, "STA": 2},
            new_streak=16,
            message="Great job! Your streak is now 16 days!",
        )

        assert response.success is True
        assert response.item_code == "morning_workout"
        assert response.completed_at == completed_time
        assert response.xp_granted == {"STR": 3, "STA": 2}
        assert response.new_streak == 16
        assert "16 days" in response.message


class TestCalendarEvent:
    """Test CalendarEvent Pydantic model"""

    def test_calendar_event_minimal(self):
        """Test calendar event with minimal fields"""
        event_id = uuid4()
        start = datetime.utcnow()
        event = CalendarEvent(
            id=event_id,
            title="Team Meeting",
            start_time=start,
            all_day=False,
            event_type="event",
            source="google",
        )

        assert event.id == event_id
        assert event.title == "Team Meeting"
        assert event.start_time == start
        assert event.all_day is False
        assert event.source == "google"

    def test_calendar_event_full(self):
        """Test calendar event with all fields"""
        event_id = uuid4()
        start = datetime.utcnow()
        end = datetime.utcnow()
        event = CalendarEvent(
            id=event_id,
            title="Conference",
            description="Annual company conference",
            location="Oslo Convention Center",
            start_time=start,
            end_time=end,
            all_day=False,
            event_type="meeting",
            source="outlook",
        )

        assert event.title == "Conference"
        assert event.description == "Annual company conference"
        assert event.location == "Oslo Convention Center"
        assert event.end_time == end

    def test_calendar_event_all_day(self):
        """Test all-day calendar event"""
        event_id = uuid4()
        start = datetime.utcnow()
        event = CalendarEvent(
            id=event_id,
            title="Holiday",
            start_time=start,
            all_day=True,
            event_type="event",
            source="google",
        )

        assert event.all_day is True
        assert event.end_time is None


class TestTimelineModelIntegration:
    """Integration tests for timeline model relationships"""

    def test_timeline_item_to_feed_item_conversion(self):
        """Test that TimelineItem data can populate TimelineFeedItem"""
        item_id = uuid4()
        timeline_item = TimelineItem(
            id=item_id,
            code="morning_workout",
            name="Morning Workout",
            description="30 min cardio",
            icon="🏃",
            schedule_type="daily",
            schedule_days=[],
            time_offset=0,
            window_minutes=60,
            stat_rewards={"STR": 3},
            priority=8,
            category="habit",
            is_active=True,
        )

        # Feed item derived from timeline item
        feed_item = TimelineFeedItem(
            id=timeline_item.id,
            code=timeline_item.code,
            name=timeline_item.name,
            description=timeline_item.description,
            icon=timeline_item.icon,
            category=timeline_item.category,
            scheduled_time=time(6, 30),
            window_end=time(7, 30),
            status="upcoming",
            stat_rewards=timeline_item.stat_rewards,
        )

        assert feed_item.id == timeline_item.id
        assert feed_item.code == timeline_item.code
        assert feed_item.stat_rewards == timeline_item.stat_rewards

    def test_postpone_workflow(self):
        """Test postpone request and response workflow"""
        # User requests postpone
        request = PostponeRequest(
            target=PostponeTarget.TOMORROW_MORNING,
            reason="Not feeling well today",
        )

        # System processes and responds
        original = date.today()
        new = date(2026, 6, 15)
        response = PostponeResponse(
            success=True,
            item_code="morning_workout",
            original_date=original,
            new_date=new,
            new_time=time(6, 30),
            message="Workout postponed to tomorrow morning at 6:30 AM",
        )

        assert request.reason == "Not feeling well today"
        assert response.success is True
        assert response.new_date > response.original_date

    def test_complete_workflow(self):
        """Test complete request and response workflow"""
        # User completes task
        request = CompleteRequest(
            notes="Finished early, felt great!",
            duration_minutes=35,
        )

        # System records completion
        response = CompleteResponse(
            success=True,
            item_code="morning_workout",
            completed_at=datetime.utcnow(),
            xp_granted={"STR": 3, "STA": 2},
            new_streak=20,
            message="Milestone! You've reached a 20-day streak!",
        )

        assert request.duration_minutes == 35
        assert response.success is True
        assert response.new_streak == 20
        assert sum(response.xp_granted.values()) == 5
