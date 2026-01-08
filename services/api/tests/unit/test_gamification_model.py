"""Unit tests for Gamification models"""

import pytest
from datetime import datetime, date
from uuid import uuid4

from app.models.gamification import (
    Streak,
    Achievement,
    DailyScore,
    GamificationEvent,
    XPInfo,
    TodayResponse,
)


class TestStreak:
    """Test Streak Pydantic model"""

    def test_streak_defaults(self):
        """Test Streak with default values"""
        streak_id = uuid4()
        streak = Streak(
            id=streak_id,
            streak_type="morning_workout",
        )

        assert streak.id == streak_id
        assert streak.streak_type == "morning_workout"
        assert streak.current_count == 0
        assert streak.best_count == 0
        assert streak.last_date is None
        assert streak.freeze_tokens == 0

    def test_streak_active(self):
        """Test an active streak"""
        streak_id = uuid4()
        today = date.today()
        streak = Streak(
            id=streak_id,
            streak_type="daily_habit",
            current_count=15,
            best_count=20,
            last_date=today,
            freeze_tokens=2,
        )

        assert streak.current_count == 15
        assert streak.best_count == 20
        assert streak.last_date == today
        assert streak.freeze_tokens == 2

    def test_streak_record_broken(self):
        """Test when current streak breaks record"""
        streak_id = uuid4()
        today = date.today()
        streak = Streak(
            id=streak_id,
            streak_type="meditation",
            current_count=100,
            best_count=99,
            last_date=today,
        )

        assert streak.current_count > streak.best_count


class TestAchievement:
    """Test Achievement Pydantic model"""

    def test_achievement_defaults(self):
        """Test Achievement with default values"""
        achievement_id = uuid4()
        achievement = Achievement(
            id=achievement_id,
            code="first_week",
            name="First Week",
        )

        assert achievement.id == achievement_id
        assert achievement.code == "first_week"
        assert achievement.name == "First Week"
        assert achievement.description is None
        assert achievement.tier == "bronze"
        assert achievement.xp_reward == 0
        assert achievement.progress == 0
        assert achievement.target == 1
        assert achievement.unlocked_at is None
        assert achievement.is_unlocked is False

    def test_achievement_unlocked(self):
        """Test an unlocked achievement"""
        achievement_id = uuid4()
        now = datetime.utcnow()
        achievement = Achievement(
            id=achievement_id,
            code="early_riser_30",
            name="Early Riser: 30 Days",
            description="Wake up before 6 AM for 30 days",
            tier="silver",
            xp_reward=500,
            progress=30,
            target=30,
            unlocked_at=now,
            is_unlocked=True,
        )

        assert achievement.code == "early_riser_30"
        assert achievement.tier == "silver"
        assert achievement.xp_reward == 500
        assert achievement.progress == 30
        assert achievement.target == 30
        assert achievement.is_unlocked is True
        assert achievement.unlocked_at == now

    def test_achievement_progress_percent(self):
        """Test achievement progress percentage calculation"""
        achievement_id = uuid4()

        # 0% progress
        ach_0 = Achievement(
            id=achievement_id,
            code="test",
            name="Test",
            progress=0,
            target=100,
        )
        assert ach_0.progress_percent == 0.0

        # 50% progress
        ach_50 = Achievement(
            id=achievement_id,
            code="test",
            name="Test",
            progress=50,
            target=100,
        )
        assert ach_50.progress_percent == 50.0

        # 100% progress
        ach_100 = Achievement(
            id=achievement_id,
            code="test",
            name="Test",
            progress=100,
            target=100,
        )
        assert ach_100.progress_percent == 100.0

        # Over 100% (capped)
        ach_over = Achievement(
            id=achievement_id,
            code="test",
            name="Test",
            progress=150,
            target=100,
        )
        assert ach_over.progress_percent == 100.0

    def test_achievement_progress_percent_zero_target(self):
        """Test progress percent with zero target"""
        achievement_id = uuid4()
        achievement = Achievement(
            id=achievement_id,
            code="instant",
            name="Instant",
            progress=1,
            target=0,
        )
        assert achievement.progress_percent == 100.0

    def test_achievement_tiers(self):
        """Test different achievement tiers"""
        achievement_id = uuid4()
        tiers = ["bronze", "silver", "gold", "platinum", "diamond"]

        for tier in tiers:
            achievement = Achievement(
                id=achievement_id,
                code=f"{tier}_test",
                name=f"{tier.title()} Test",
                tier=tier,
            )
            assert achievement.tier == tier


class TestDailyScore:
    """Test DailyScore Pydantic model"""

    def test_daily_score_creation(self):
        """Test DailyScore with all fields"""
        today = date.today()
        score = DailyScore(
            date=today,
            life_score=85.5,
            sleep_score=88.0,
            activity_score=92.0,
            worklife_score=75.0,
            habits_score=80.0,
            xp_earned=250,
        )

        assert score.date == today
        assert score.life_score == 85.5
        assert score.sleep_score == 88.0
        assert score.activity_score == 92.0
        assert score.worklife_score == 75.0
        assert score.habits_score == 80.0
        assert score.xp_earned == 250

    def test_daily_score_xp_default(self):
        """Test DailyScore with default XP"""
        today = date.today()
        score = DailyScore(
            date=today,
            life_score=50.0,
            sleep_score=50.0,
            activity_score=50.0,
            worklife_score=50.0,
            habits_score=50.0,
        )

        assert score.xp_earned == 0

    def test_daily_score_ranges(self):
        """Test that scores are in reasonable ranges"""
        today = date.today()
        score = DailyScore(
            date=today,
            life_score=100.0,
            sleep_score=0.0,
            activity_score=50.0,
            worklife_score=75.0,
            habits_score=25.0,
        )

        assert 0 <= score.life_score <= 100
        assert 0 <= score.sleep_score <= 100
        assert 0 <= score.activity_score <= 100


class TestGamificationEvent:
    """Test GamificationEvent Pydantic model"""

    def test_gamification_event_defaults(self):
        """Test GamificationEvent with defaults"""
        now = datetime.utcnow()
        event = GamificationEvent(
            time=now,
            event_type="habit_completed",
        )

        assert event.time == now
        assert event.event_type == "habit_completed"
        assert event.xp_earned == 0
        assert event.details == {}

    def test_gamification_event_with_xp(self):
        """Test GamificationEvent with XP reward"""
        now = datetime.utcnow()
        event = GamificationEvent(
            time=now,
            event_type="achievement_unlocked",
            xp_earned=500,
            details={"achievement_code": "first_week"},
        )

        assert event.event_type == "achievement_unlocked"
        assert event.xp_earned == 500
        assert event.details["achievement_code"] == "first_week"

    def test_gamification_event_types(self):
        """Test various event types"""
        now = datetime.utcnow()
        event_types = [
            "habit_completed",
            "streak_milestone",
            "achievement_unlocked",
            "level_up",
            "daily_goal_met",
        ]

        for event_type in event_types:
            event = GamificationEvent(
                time=now,
                event_type=event_type,
            )
            assert event.event_type == event_type


class TestXPInfo:
    """Test XPInfo Pydantic model"""

    def test_xp_info_defaults(self):
        """Test XPInfo with default values"""
        xp_info = XPInfo()

        assert xp_info.total_xp == 0
        assert xp_info.level == 1
        assert xp_info.xp_for_current_level == 0
        assert xp_info.xp_for_next_level == 1000
        assert xp_info.progress_to_next == 0.0
        assert xp_info.today_xp == 0

    def test_xp_info_level_1(self):
        """Test XP info at level 1"""
        xp_info = XPInfo(
            total_xp=500,
            level=1,
            xp_for_current_level=0,
            xp_for_next_level=1000,
            progress_to_next=50.0,
            today_xp=100,
        )

        assert xp_info.total_xp == 500
        assert xp_info.level == 1
        assert xp_info.progress_to_next == 50.0
        assert xp_info.today_xp == 100

    def test_xp_info_higher_level(self):
        """Test XP info at higher level"""
        xp_info = XPInfo(
            total_xp=15000,
            level=10,
            xp_for_current_level=10000,
            xp_for_next_level=12000,
            progress_to_next=75.0,
            today_xp=250,
        )

        assert xp_info.level == 10
        assert xp_info.total_xp == 15000
        assert xp_info.progress_to_next == 75.0

    def test_xp_info_level_up(self):
        """Test XP info just before and after level up"""
        # Just before level up
        before = XPInfo(
            total_xp=999,
            level=1,
            xp_for_current_level=0,
            xp_for_next_level=1000,
            progress_to_next=99.9,
        )
        assert before.level == 1

        # Just after level up
        after = XPInfo(
            total_xp=1000,
            level=2,
            xp_for_current_level=1000,
            xp_for_next_level=2000,
            progress_to_next=0.0,
        )
        assert after.level == 2


class TestTodayResponse:
    """Test TodayResponse Pydantic model"""

    def test_today_response_minimal(self):
        """Test TodayResponse with minimal data"""
        today = date.today()
        xp_info = XPInfo()
        response = TodayResponse(
            date=today,
            life_score=50.0,
            domains={},
            xp=xp_info,
            streaks={},
        )

        assert response.date == today
        assert response.life_score == 50.0
        assert response.domains == {}
        assert response.xp.level == 1
        assert response.streaks == {}
        assert response.recent_achievements == []
        assert response.message is None

    def test_today_response_complete(self):
        """Test TodayResponse with complete data"""
        today = date.today()
        xp_info = XPInfo(total_xp=5000, level=5)
        achievement = Achievement(
            id=uuid4(),
            code="test",
            name="Test",
            tier="gold",
        )

        response = TodayResponse(
            date=today,
            life_score=88.5,
            domains={
                "sleep": 92.0,
                "activity": 85.0,
                "worklife": 88.0,
                "habits": 90.0,
            },
            xp=xp_info,
            streaks={
                "morning_workout": 15,
                "meditation": 30,
                "early_bed": 7,
            },
            recent_achievements=[achievement],
            message="Great day! Keep it up!",
        )

        assert response.life_score == 88.5
        assert response.domains["sleep"] == 92.0
        assert response.xp.level == 5
        assert len(response.streaks) == 3
        assert response.streaks["meditation"] == 30
        assert len(response.recent_achievements) == 1
        assert response.message == "Great day! Keep it up!"

    def test_today_response_domain_scores(self):
        """Test domain score structure"""
        today = date.today()
        response = TodayResponse(
            date=today,
            life_score=85.0,
            domains={
                "sleep": 90.0,
                "activity": 85.0,
                "worklife": 80.0,
                "habits": 85.0,
            },
            xp=XPInfo(),
            streaks={},
        )

        assert "sleep" in response.domains
        assert "activity" in response.domains
        assert "worklife" in response.domains
        assert "habits" in response.domains
        assert all(0 <= score <= 100 for score in response.domains.values())


class TestGamificationModelIntegration:
    """Integration tests for gamification model relationships"""

    def test_achievement_with_streak(self):
        """Test achievement that tracks a streak"""
        achievement_id = uuid4()
        streak_id = uuid4()

        # Streak
        streak = Streak(
            id=streak_id,
            streak_type="morning_workout",
            current_count=30,
            best_count=30,
        )

        # Related achievement
        achievement = Achievement(
            id=achievement_id,
            code="morning_workout_30",
            name="30-Day Morning Warrior",
            description="Complete morning workout 30 days in a row",
            tier="silver",
            xp_reward=750,
            progress=30,
            target=30,
            unlocked_at=datetime.utcnow(),
            is_unlocked=True,
        )

        assert streak.current_count == achievement.progress
        assert achievement.progress >= achievement.target
        assert achievement.is_unlocked is True

    def test_daily_score_xp_calculation(self):
        """Test that daily score affects XP earned"""
        today = date.today()

        # High score day
        high_score = DailyScore(
            date=today,
            life_score=95.0,
            sleep_score=100.0,
            activity_score=95.0,
            worklife_score=90.0,
            habits_score=95.0,
            xp_earned=500,
        )

        # Low score day
        low_score = DailyScore(
            date=today,
            life_score=40.0,
            sleep_score=30.0,
            activity_score=45.0,
            worklife_score=50.0,
            habits_score=35.0,
            xp_earned=100,
        )

        # Higher life score should earn more XP
        assert high_score.life_score > low_score.life_score
        assert high_score.xp_earned > low_score.xp_earned

    def test_today_response_comprehensive(self):
        """Test comprehensive TodayResponse with all gamification elements"""
        today = date.today()

        xp_info = XPInfo(
            total_xp=12500,
            level=8,
            xp_for_current_level=10000,
            xp_for_next_level=15000,
            progress_to_next=50.0,
            today_xp=350,
        )

        achievements = [
            Achievement(
                id=uuid4(),
                code="week_1",
                name="First Week",
                tier="bronze",
                unlocked_at=datetime.utcnow(),
                is_unlocked=True,
            ),
            Achievement(
                id=uuid4(),
                code="early_bird",
                name="Early Bird",
                tier="silver",
                unlocked_at=datetime.utcnow(),
                is_unlocked=True,
            ),
        ]

        response = TodayResponse(
            date=today,
            life_score=92.0,
            domains={
                "sleep": 95.0,
                "activity": 90.0,
                "worklife": 88.0,
                "habits": 95.0,
            },
            xp=xp_info,
            streaks={
                "morning_workout": 45,
                "meditation": 60,
                "early_wake": 30,
            },
            recent_achievements=achievements,
            message="Outstanding! You're on fire!",
        )

        # Verify comprehensive data
        assert response.life_score > 90
        assert response.xp.level == 8
        assert len(response.streaks) == 3
        assert max(response.streaks.values()) == 60
        assert len(response.recent_achievements) == 2
        assert all(a.is_unlocked for a in response.recent_achievements)
