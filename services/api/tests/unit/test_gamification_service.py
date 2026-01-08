"""Unit tests for Gamification service"""

import pytest
from datetime import date, datetime, time, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
import math

from app.services.gamification import (
    GamificationService,
    xp_for_level,
    level_from_xp,
    xp_progress_in_level,
    BONUS_XP
)
from app.models.gamification import DailyScore, XPInfo


class TestXPCalculations:
    """Test suite for XP and level calculations"""

    def test_xp_for_level(self):
        """Test XP required for levels"""
        assert xp_for_level(1) == 1000
        assert xp_for_level(2) == 4000
        assert xp_for_level(3) == 9000
        assert xp_for_level(10) == 100000

    def test_level_from_xp(self):
        """Test level calculation from total XP"""
        assert level_from_xp(0) == 1
        assert level_from_xp(1000) == 1
        assert level_from_xp(4000) == 2
        assert level_from_xp(5000) == 2
        assert level_from_xp(9000) == 3
        assert level_from_xp(100000) == 10

    def test_xp_progress_in_level(self):
        """Test XP progress within current level"""
        # At level 1 with 500 XP
        xp_into, xp_needed, progress = xp_progress_in_level(500)
        assert xp_into == 500
        assert xp_needed == 1000
        assert progress == 50.0

        # At level 2 with 2500 XP (500 into level 2)
        xp_into, xp_needed, progress = xp_progress_in_level(2500)
        assert xp_into == 1500
        assert xp_needed == 3000
        assert progress == 50.0

    def test_xp_progress_at_level_boundary(self):
        """Test XP progress exactly at level boundary"""
        xp_into, xp_needed, progress = xp_progress_in_level(1000)
        assert xp_into == 1000
        assert xp_needed == 3000
        assert abs(progress - 33.33) < 0.1


class TestGamificationService:
    """Test suite for GamificationService"""

    @pytest.fixture
    def service(self):
        with patch('app.services.gamification.settings') as mock_settings:
            mock_settings.sleep_weight = 0.40
            mock_settings.activity_weight = 0.25
            mock_settings.worklife_weight = 0.20
            mock_settings.habits_weight = 0.15
            return GamificationService()

    # ===========================================
    # Sleep Score Tests
    # ===========================================

    def test_calculate_sleep_score_perfect(self, service):
        """Test perfect sleep score calculation"""
        score = service.calculate_sleep_score(
            oura_sleep_score=100,
            wake_time=time(6, 0),
            target_wake=time(6, 0),
            bedtime=time(22, 0),
            target_bedtime=time(22, 30),
            screens_off_30min=True
        )
        # Oura: 100*0.6=60, Schedule: 100*0.25=25, Routine: 100*0.15=15
        assert score == 100.0

    def test_calculate_sleep_score_no_oura(self, service):
        """Test sleep score with missing Oura data"""
        score = service.calculate_sleep_score(
            oura_sleep_score=None
        )
        # Should use default of 50 for Oura component
        assert score > 0
        assert score < 100

    def test_calculate_sleep_score_late_wake(self, service):
        """Test sleep score with late wake time"""
        score = service.calculate_sleep_score(
            oura_sleep_score=85,
            wake_time=time(8, 0),  # 2 hours late = 120 minutes
            target_wake=time(6, 0)
        )
        # Schedule component should be 0 (100 - 120*2 = -140 -> 0)
        assert score < 85
        assert score == pytest.approx(51.0)  # 85*0.6 + 0*0.25 + 50*0.15

    def test_calculate_sleep_score_early_wake(self, service):
        """Test sleep score with early wake time"""
        score = service.calculate_sleep_score(
            oura_sleep_score=85,
            wake_time=time(5, 30),  # 30 minutes early
            target_wake=time(6, 0)
        )
        # Schedule: 100 - 30*2 = 40
        assert score == pytest.approx(61.0)  # 85*0.6 + 40*0.25 + 50*0.15

    def test_calculate_sleep_score_good_routine(self, service):
        """Test sleep score with good pre-bed routine"""
        score = service.calculate_sleep_score(
            oura_sleep_score=80,
            bedtime=time(22, 0),
            target_bedtime=time(22, 30),
            screens_off_30min=True
        )
        # Routine: 50 + 30 (on time) + 20 (screens off) = 100
        assert score == pytest.approx(88.0)  # 80*0.6 + 100*0.25 + 100*0.15

    # ===========================================
    # Activity Score Tests
    # ===========================================

    def test_calculate_activity_score_perfect(self, service):
        """Test perfect activity score"""
        score = service.calculate_activity_score(
            oura_activity_score=100,
            gym_sessions_this_week=3,
            target_sessions=3,
            steps_today=10000
        )
        # Oura: 100*0.4=40, Gym: 100*0.4=40, Steps: 100*0.2=20
        assert score == 100.0

    def test_calculate_activity_score_no_oura(self, service):
        """Test activity score without Oura data"""
        score = service.calculate_activity_score(
            oura_activity_score=None,
            gym_sessions_this_week=2,
            steps_today=7000
        )
        # Uses default 50 for Oura
        assert score > 0

    def test_calculate_activity_score_step_thresholds(self, service):
        """Test activity score at various step counts"""
        # 10k+ steps = 100
        score1 = service.calculate_activity_score(
            oura_activity_score=50, steps_today=10000
        )
        # 7k steps = 90
        score2 = service.calculate_activity_score(
            oura_activity_score=50, steps_today=7000
        )
        # 5k steps = 70
        score3 = service.calculate_activity_score(
            oura_activity_score=50, steps_today=5000
        )
        # 3k steps = 40
        score4 = service.calculate_activity_score(
            oura_activity_score=50, steps_today=3000
        )

        assert score1 > score2 > score3 > score4

    def test_calculate_activity_score_gym_sessions(self, service):
        """Test activity score with varying gym sessions"""
        # No gym = 0
        score1 = service.calculate_activity_score(
            oura_activity_score=50, gym_sessions_this_week=0, target_sessions=3
        )
        # 1/3 sessions = 33%
        score2 = service.calculate_activity_score(
            oura_activity_score=50, gym_sessions_this_week=1, target_sessions=3
        )
        # 3/3 sessions = 100%
        score3 = service.calculate_activity_score(
            oura_activity_score=50, gym_sessions_this_week=3, target_sessions=3
        )
        # Over target capped at 100%
        score4 = service.calculate_activity_score(
            oura_activity_score=50, gym_sessions_this_week=5, target_sessions=3
        )

        assert score3 > score2 > score1
        assert score4 == score3

    # ===========================================
    # Work-Life Score Tests
    # ===========================================

    def test_calculate_worklife_score_perfect(self, service):
        """Test perfect work-life score"""
        score = service.calculate_worklife_score(
            work_hours_today=8.0,
            work_cutoff_hour=17,
            weekend_work_hours=0.0,
            is_weekend=False
        )
        assert score == 100.0

    def test_calculate_worklife_score_overtime(self, service):
        """Test work-life score with overtime"""
        score = service.calculate_worklife_score(
            work_hours_today=11.0,  # 3 hours overtime
            work_cutoff_hour=20,
            is_weekend=False
        )
        # Hours: 30*0.4=12, Cutoff: 50*0.35=17.5, Weekend: 80*0.25=20
        assert score == pytest.approx(49.5)

    def test_calculate_worklife_score_weekend_work(self, service):
        """Test work-life score with weekend work"""
        score = service.calculate_worklife_score(
            work_hours_today=4.0,
            work_cutoff_hour=17,
            weekend_work_hours=3.0,
            is_weekend=True
        )
        # Should penalize weekend work
        assert score < 100

    def test_calculate_worklife_score_late_cutoff(self, service):
        """Test work-life score with late work cutoff"""
        score1 = service.calculate_worklife_score(work_cutoff_hour=17)
        score2 = service.calculate_worklife_score(work_cutoff_hour=19)
        score3 = service.calculate_worklife_score(work_cutoff_hour=22)

        assert score1 > score2 > score3

    # ===========================================
    # Habits Score Tests
    # ===========================================

    def test_calculate_habits_score_perfect(self, service):
        """Test perfect habits score"""
        score = service.calculate_habits_score(
            screen_hours=1.5,
            habits_completed=5,
            habits_total=5
        )
        assert score == 100.0

    def test_calculate_habits_score_screen_time(self, service):
        """Test habits score with varying screen time"""
        score1 = service.calculate_habits_score(screen_hours=1.5)
        score2 = service.calculate_habits_score(screen_hours=2.5)
        score3 = service.calculate_habits_score(screen_hours=3.5)
        score4 = service.calculate_habits_score(screen_hours=5.5)

        assert score1 > score2 > score3 > score4

    def test_calculate_habits_score_checklist(self, service):
        """Test habits score with habit checklist"""
        score1 = service.calculate_habits_score(habits_completed=5, habits_total=5)
        score2 = service.calculate_habits_score(habits_completed=3, habits_total=5)
        score3 = service.calculate_habits_score(habits_completed=0, habits_total=5)

        assert score1 > score2 > score3

    def test_calculate_habits_score_no_habits_defined(self, service):
        """Test habits score when no habits are defined"""
        score = service.calculate_habits_score(
            screen_hours=3.0,
            habits_completed=0,
            habits_total=0
        )
        # Should use neutral 50 for checklist component
        assert score > 0

    # ===========================================
    # Life Score Tests
    # ===========================================

    def test_calculate_life_score(self, service):
        """Test overall Life Score calculation"""
        score = service.calculate_life_score(
            sleep_score=90.0,
            activity_score=80.0,
            worklife_score=85.0,
            habits_score=75.0
        )
        # Weighted: 90*0.4 + 80*0.25 + 85*0.2 + 75*0.15 = 36+20+17+11.25 = 84.25
        assert score == pytest.approx(84.2, abs=0.1)

    def test_calculate_life_score_perfect(self, service):
        """Test perfect Life Score"""
        score = service.calculate_life_score(100.0, 100.0, 100.0, 100.0)
        assert score == 100.0

    def test_calculate_life_score_weights(self, service):
        """Test that weights are applied correctly"""
        # High sleep should dominate (40% weight)
        score_high_sleep = service.calculate_life_score(100, 0, 0, 0)
        # High activity (25% weight)
        score_high_activity = service.calculate_life_score(0, 100, 0, 0)

        assert score_high_sleep > score_high_activity

    # ===========================================
    # Database Operations Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_calculate_daily_score_with_oura_data(self, service, mock_db_session):
        """Test calculating daily score with Oura data from DB"""
        target_date = date(2026, 1, 1)

        # Mock Oura summary in database
        mock_summary = MagicMock()
        mock_summary.sleep_score = 85
        mock_summary.activity_score = 80
        mock_summary.readiness_score = 75
        mock_summary.sleep_data = {}
        mock_summary.activity_data = {"steps": 8500}

        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_summary
        mock_db_session.execute.return_value = mock_result

        result = await service.calculate_daily_score(
            mock_db_session,
            target_date
        )

        assert isinstance(result, DailyScore)
        assert result.date == target_date
        assert result.life_score > 0
        assert result.xp_earned > 0

    @pytest.mark.asyncio
    async def test_calculate_daily_score_no_oura_data(self, service, mock_db_session):
        """Test calculating daily score without Oura data"""
        target_date = date(2026, 1, 1)

        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_result

        result = await service.calculate_daily_score(
            mock_db_session,
            target_date
        )

        assert isinstance(result, DailyScore)
        assert result.life_score > 0  # Should use defaults

    @pytest.mark.asyncio
    async def test_calculate_daily_score_bonus_xp(self, service, mock_db_session):
        """Test bonus XP awards"""
        target_date = date(2026, 1, 1)

        # Mock perfect Oura scores for bonus XP
        mock_summary = MagicMock()
        mock_summary.sleep_score = 100  # Perfect sleep = 200 bonus
        mock_summary.activity_score = 90
        mock_summary.readiness_score = 85
        mock_summary.sleep_data = {}
        mock_summary.activity_data = {"steps": 10500}  # 10k+ = 100 bonus

        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_summary
        mock_db_session.execute.return_value = mock_result

        result = await service.calculate_daily_score(
            mock_db_session,
            target_date
        )

        # Should include base XP + bonuses
        expected_bonus = BONUS_XP["perfect_sleep_score"] + BONUS_XP["steps_10k"]
        assert result.xp_earned > 700  # Base + bonuses

    @pytest.mark.asyncio
    async def test_get_daily_score(self, service, mock_db_session):
        """Test retrieving daily score from DB"""
        target_date = date(2026, 1, 1)

        mock_row = MagicMock()
        mock_row.date = target_date
        mock_row.life_score = 85.0
        mock_row.sleep_score = 90.0
        mock_row.activity_score = 80.0
        mock_row.worklife_score = 85.0
        mock_row.habits_score = 75.0
        mock_row.xp_earned = 850

        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_row
        mock_db_session.execute.return_value = mock_result

        result = await service.get_daily_score(mock_db_session, target_date)

        assert result.life_score == 85.0
        assert result.xp_earned == 850

    @pytest.mark.asyncio
    async def test_get_daily_score_not_found(self, service, mock_db_session):
        """Test getting daily score when none exists"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_result

        result = await service.get_daily_score(mock_db_session, date.today())

        assert result is None

    @pytest.mark.asyncio
    async def test_get_xp_info(self, service, mock_db_session):
        """Test getting XP information"""
        # Mock user profile
        mock_user = MagicMock()
        mock_user.total_xp = 5000  # Level 2

        # Mock today's XP
        mock_today_xp = 850

        mock_result1 = AsyncMock()
        mock_result1.scalar_one_or_none.return_value = mock_user

        mock_result2 = AsyncMock()
        mock_result2.scalar_one_or_none.return_value = mock_today_xp

        mock_db_session.execute.side_effect = [mock_result1, mock_result2]

        result = await service.get_xp_info(mock_db_session)

        assert isinstance(result, XPInfo)
        assert result.total_xp == 5000
        assert result.level == 2
        assert result.today_xp == 850

    @pytest.mark.asyncio
    async def test_get_xp_info_no_user(self, service, mock_db_session):
        """Test getting XP info when no user exists"""
        mock_result1 = AsyncMock()
        mock_result1.scalar_one_or_none.return_value = None

        mock_result2 = AsyncMock()
        mock_result2.scalar_one_or_none.return_value = 0

        mock_db_session.execute.side_effect = [mock_result1, mock_result2]

        result = await service.get_xp_info(mock_db_session)

        assert result.total_xp == 0
        assert result.level == 1

    @pytest.mark.asyncio
    async def test_add_xp(self, service, mock_db_session):
        """Test adding XP"""
        await service.add_xp(
            mock_db_session,
            xp_amount=200,
            event_type="bonus_achievement",
            details={"achievement": "first_workout"}
        )

        # Should have executed UPDATE and INSERT queries
        assert mock_db_session.execute.call_count == 2
        mock_db_session.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_streaks(self, service, mock_db_session):
        """Test getting streaks"""
        mock_streak1 = MagicMock()
        mock_streak1.streak_type = "morning_victory"
        mock_streak1.current_count = 5

        mock_streak2 = MagicMock()
        mock_streak2.streak_type = "gym_chain"
        mock_streak2.current_count = 12

        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = [mock_streak1, mock_streak2]
        mock_db_session.execute.return_value = mock_result

        result = await service.get_streaks(mock_db_session)

        assert result["morning_victory"] == 5
        assert result["gym_chain"] == 12

    @pytest.mark.asyncio
    async def test_get_achievements_all(self, service, mock_db_session):
        """Test getting all achievements"""
        mock_achievement = MagicMock()
        mock_achievement.id = 1
        mock_achievement.code = "first_workout"
        mock_achievement.name = "First Workout"
        mock_achievement.description = "Complete your first workout"
        mock_achievement.tier = "bronze"
        mock_achievement.xp_reward = 200
        mock_achievement.progress = 1
        mock_achievement.target = 1
        mock_achievement.unlocked_at = datetime.utcnow()

        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = [mock_achievement]
        mock_db_session.execute.return_value = mock_result

        result = await service.get_achievements(mock_db_session)

        assert len(result) == 1
        assert result[0].code == "first_workout"
        assert result[0].is_unlocked is True

    @pytest.mark.asyncio
    async def test_get_achievements_unlocked_only(self, service, mock_db_session):
        """Test getting only unlocked achievements"""
        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db_session.execute.return_value = mock_result

        result = await service.get_achievements(mock_db_session, unlocked_only=True)

        assert len(result) == 0

    @pytest.mark.asyncio
    async def test_get_today_response(self, service, mock_db_session):
        """Test getting complete today response"""
        # Mock daily score
        with patch.object(service, 'get_daily_score', return_value=None), \
             patch.object(service, 'calculate_daily_score') as mock_calc, \
             patch.object(service, 'get_xp_info') as mock_xp, \
             patch.object(service, 'get_streaks', return_value={}) as mock_streaks:

            mock_calc.return_value = DailyScore(
                date=date.today(),
                life_score=85.0,
                sleep_score=90.0,
                activity_score=80.0,
                worklife_score=85.0,
                habits_score=75.0,
                xp_earned=850
            )

            mock_xp.return_value = XPInfo(
                total_xp=5000,
                level=2,
                xp_for_current_level=1000,
                xp_for_next_level=3000,
                progress_to_next=33.3,
                today_xp=850
            )

            # Mock recent achievements query
            mock_result = AsyncMock()
            mock_result.scalars.return_value.all.return_value = []
            mock_db_session.execute.return_value = mock_result

            result = await service.get_today_response(mock_db_session)

            assert result.life_score == 85.0
            assert result.xp.level == 2
            assert result.message == "Great job today!"

    @pytest.mark.asyncio
    async def test_get_today_response_messages(self, service, mock_db_session):
        """Test message generation based on Life Score"""
        async def test_message_for_score(score: float, expected_keyword: str):
            with patch.object(service, 'get_daily_score', return_value=None), \
                 patch.object(service, 'calculate_daily_score') as mock_calc, \
                 patch.object(service, 'get_xp_info') as mock_xp, \
                 patch.object(service, 'get_streaks', return_value={}):

                mock_calc.return_value = DailyScore(
                    date=date.today(), life_score=score, sleep_score=0,
                    activity_score=0, worklife_score=0, habits_score=0, xp_earned=0
                )
                mock_xp.return_value = XPInfo(
                    total_xp=0, level=1, xp_for_current_level=0,
                    xp_for_next_level=1000, progress_to_next=0, today_xp=0
                )

                mock_result = AsyncMock()
                mock_result.scalars.return_value.all.return_value = []
                mock_db_session.execute.return_value = mock_result

                result = await service.get_today_response(mock_db_session)
                assert expected_keyword.lower() in result.message.lower()

        await test_message_for_score(95.0, "outstanding")
        await test_message_for_score(85.0, "great")
        await test_message_for_score(75.0, "solid")
        await test_message_for_score(55.0, "tough")
