"""Gamification engine - Life Score calculations, XP, streaks, achievements"""

from datetime import date, datetime, time, timedelta
from typing import Optional, Any
import logging
import math

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.config import settings
from app.models.gamification import (
    StreakDB, AchievementDB, DailyScoreDB, GamificationEventDB,
    DailyScore, Streak, Achievement, XPInfo, TodayResponse
)
from app.models.user import UserProfileDB
from app.models.health import DailySummaryDB

logger = logging.getLogger(__name__)


# ===========================================
# XP and Level Calculations
# ===========================================

def xp_for_level(level: int) -> int:
    """Calculate total XP required to reach a level"""
    # Quadratic progression: 1000, 4000, 9000, 16000...
    return 1000 * level * level


def level_from_xp(total_xp: int) -> int:
    """Calculate level from total XP"""
    # Inverse of quadratic: level = sqrt(xp / 1000)
    return max(1, int(math.sqrt(total_xp / 1000)))


def xp_progress_in_level(total_xp: int) -> tuple[int, int, float]:
    """
    Calculate XP progress within current level.
    Returns: (xp_into_level, xp_needed_for_next, progress_percent)
    """
    level = level_from_xp(total_xp)
    xp_for_current = xp_for_level(level - 1) if level > 1 else 0
    xp_for_next = xp_for_level(level)

    xp_into = total_xp - xp_for_current
    xp_needed = xp_for_next - xp_for_current
    progress = (xp_into / xp_needed * 100) if xp_needed > 0 else 100.0

    return xp_into, xp_needed, progress


# ===========================================
# Bonus XP Events
# ===========================================

BONUS_XP = {
    "perfect_sleep_score": 200,      # Oura sleep score = 100
    "excellent_sleep": 100,          # Oura sleep score >= 85
    "gym_session": 150,              # Logged gym visit
    "early_work_cutoff": 100,        # Stopped work before 6 PM
    "all_habits_complete": 150,      # Completed all daily habits
    "life_score_90_plus": 300,       # Life Score >= 90
    "life_score_95_plus": 500,       # Life Score >= 95
    "steps_10k": 100,                # 10,000+ steps
    "sub_2hr_screen": 200,           # Screen time < 2 hours
    "early_wake": 100,               # Woke before target time
    "on_time_bed": 100,              # In bed by target time
}


class GamificationService:
    """Service for gamification logic and calculations"""

    def __init__(self):
        self.weights = {
            "sleep": settings.sleep_weight,
            "activity": settings.activity_weight,
            "worklife": settings.worklife_weight,
            "habits": settings.habits_weight,
        }

    # ===========================================
    # Domain Score Calculations
    # ===========================================

    def calculate_sleep_score(
        self,
        oura_sleep_score: Optional[int],
        wake_time: Optional[time] = None,
        target_wake: time = time(6, 0),
        bedtime: Optional[time] = None,
        target_bedtime: time = time(22, 30),
        screens_off_30min: bool = False,
    ) -> float:
        """
        Calculate sleep domain score (0-100).

        Components:
        - Oura sleep score: 60%
        - Wake time consistency: 25%
        - Pre-bed routine: 15%
        """
        # Oura component (60%)
        oura_component = (oura_sleep_score or 50) * 0.60

        # Wake time consistency (25%)
        schedule_score = 100
        if wake_time:
            # Minutes deviation from target
            wake_minutes = wake_time.hour * 60 + wake_time.minute
            target_minutes = target_wake.hour * 60 + target_wake.minute
            deviation = abs(wake_minutes - target_minutes)
            # Lose 2 points per minute of deviation, max 100 points lost
            schedule_score = max(0, 100 - (deviation * 2))
        schedule_component = schedule_score * 0.25

        # Pre-bed routine (15%)
        routine_score = 50  # Base score
        if bedtime:
            bed_minutes = bedtime.hour * 60 + bedtime.minute
            target_minutes = target_bedtime.hour * 60 + target_bedtime.minute
            if bed_minutes <= target_minutes:
                routine_score += 30  # In bed on time
        if screens_off_30min:
            routine_score += 20  # Screens off before bed
        routine_component = min(100, routine_score) * 0.15

        return round(oura_component + schedule_component + routine_component, 1)

    def calculate_activity_score(
        self,
        oura_activity_score: Optional[int],
        gym_sessions_this_week: int = 0,
        target_sessions: int = 3,
        steps_today: int = 0,
    ) -> float:
        """
        Calculate activity domain score (0-100).

        Components:
        - Oura activity score: 40%
        - Gym sessions (rolling 7 days): 40%
        - Daily steps: 20%
        """
        # Oura component (40%)
        oura_component = (oura_activity_score or 50) * 0.40

        # Gym sessions (40%)
        gym_ratio = min(1.0, gym_sessions_this_week / target_sessions)
        gym_component = (gym_ratio * 100) * 0.40

        # Steps (20%)
        if steps_today >= 10000:
            steps_score = 100
        elif steps_today >= 7000:
            steps_score = 90
        elif steps_today >= 5000:
            steps_score = 70
        elif steps_today >= 3000:
            steps_score = 40
        else:
            steps_score = max(0, steps_today / 100)  # 1 point per 100 steps
        steps_component = steps_score * 0.20

        return round(oura_component + gym_component + steps_component, 1)

    def calculate_worklife_score(
        self,
        work_hours_today: float = 8.0,
        work_cutoff_hour: int = 17,
        weekend_work_hours: float = 0.0,
        is_weekend: bool = False,
    ) -> float:
        """
        Calculate work-life domain score (0-100).

        Components:
        - Work hours: 40%
        - Work cutoff time: 35%
        - Weekend recovery: 25%
        """
        # Work hours (40%)
        if work_hours_today <= 8:
            hours_score = 100
        elif work_hours_today <= 9:
            hours_score = 85
        elif work_hours_today <= 10:
            hours_score = 60
        elif work_hours_today <= 11:
            hours_score = 30
        else:
            hours_score = 0
        hours_component = hours_score * 0.40

        # Cutoff time (35%)
        if work_cutoff_hour < 17:
            cutoff_score = 100
        elif work_cutoff_hour < 18:
            cutoff_score = 100
        elif work_cutoff_hour < 19:
            cutoff_score = 80
        elif work_cutoff_hour < 20:
            cutoff_score = 50
        elif work_cutoff_hour < 21:
            cutoff_score = 20
        else:
            cutoff_score = 0
        cutoff_component = cutoff_score * 0.35

        # Weekend recovery (25%)
        if is_weekend:
            if weekend_work_hours == 0:
                weekend_score = 100
            elif weekend_work_hours < 2:
                weekend_score = 70
            elif weekend_work_hours < 4:
                weekend_score = 40
            else:
                weekend_score = 0
        else:
            weekend_score = 80  # Neutral on weekdays
        weekend_component = weekend_score * 0.25

        return round(hours_component + cutoff_component + weekend_component, 1)

    def calculate_habits_score(
        self,
        screen_hours: float = 3.0,
        habits_completed: int = 0,
        habits_total: int = 5,
    ) -> float:
        """
        Calculate habits domain score (0-100).

        Components:
        - Screen time: 50%
        - Daily checklist: 50%
        """
        # Screen time (50%)
        if screen_hours < 2:
            screen_score = 100
        elif screen_hours < 3:
            screen_score = 80
        elif screen_hours < 4:
            screen_score = 60
        elif screen_hours < 5:
            screen_score = 30
        else:
            screen_score = 0
        screen_component = screen_score * 0.50

        # Habits checklist (50%)
        if habits_total > 0:
            checklist_score = (habits_completed / habits_total) * 100
        else:
            checklist_score = 50  # Neutral if no habits defined
        checklist_component = checklist_score * 0.50

        return round(screen_component + checklist_component, 1)

    def calculate_life_score(
        self,
        sleep_score: float,
        activity_score: float,
        worklife_score: float,
        habits_score: float,
    ) -> float:
        """Calculate overall Life Score as weighted average"""
        return round(
            sleep_score * self.weights["sleep"] +
            activity_score * self.weights["activity"] +
            worklife_score * self.weights["worklife"] +
            habits_score * self.weights["habits"],
            1
        )

    # ===========================================
    # Database Operations
    # ===========================================

    async def calculate_daily_score(
        self,
        db: AsyncSession,
        target_date: date,
        oura_data: Optional[dict] = None,
        habits_data: Optional[dict] = None,
        work_data: Optional[dict] = None,
    ) -> DailyScore:
        """
        Calculate and store daily score.
        Pulls Oura data from DB if not provided.
        """
        # Get Oura data from DB if not provided
        if not oura_data:
            result = await db.execute(
                select(DailySummaryDB).where(DailySummaryDB.date == target_date)
            )
            summary = result.scalar_one_or_none()
            if summary:
                oura_data = {
                    "sleep_score": summary.sleep_score,
                    "activity_score": summary.activity_score,
                    "readiness_score": summary.readiness_score,
                    "sleep_data": summary.sleep_data or {},
                    "activity_data": summary.activity_data or {},
                }
            else:
                oura_data = {}

        # Default values
        habits_data = habits_data or {}
        work_data = work_data or {}

        # Calculate domain scores
        sleep_score = self.calculate_sleep_score(
            oura_sleep_score=oura_data.get("sleep_score"),
        )

        activity_score = self.calculate_activity_score(
            oura_activity_score=oura_data.get("activity_score"),
            steps_today=oura_data.get("activity_data", {}).get("steps", 0),
        )

        worklife_score = self.calculate_worklife_score(
            work_hours_today=work_data.get("hours", 8.0),
            work_cutoff_hour=work_data.get("cutoff_hour", 17),
            is_weekend=target_date.weekday() >= 5,
        )

        habits_score = self.calculate_habits_score(
            screen_hours=habits_data.get("screen_hours", 3.0),
            habits_completed=habits_data.get("completed", 0),
            habits_total=habits_data.get("total", 5),
        )

        # Calculate Life Score
        life_score = self.calculate_life_score(
            sleep_score, activity_score, worklife_score, habits_score
        )

        # Calculate XP
        daily_xp = int(life_score * 10)  # Base XP

        # Bonus XP
        if life_score >= 95:
            daily_xp += BONUS_XP["life_score_95_plus"]
        elif life_score >= 90:
            daily_xp += BONUS_XP["life_score_90_plus"]

        if oura_data.get("sleep_score", 0) == 100:
            daily_xp += BONUS_XP["perfect_sleep_score"]
        elif oura_data.get("sleep_score", 0) >= 85:
            daily_xp += BONUS_XP["excellent_sleep"]

        steps = oura_data.get("activity_data", {}).get("steps", 0)
        if steps >= 10000:
            daily_xp += BONUS_XP["steps_10k"]

        # Store in database
        stmt = pg_insert(DailyScoreDB).values(
            date=target_date,
            life_score=life_score,
            sleep_score=sleep_score,
            activity_score=activity_score,
            worklife_score=worklife_score,
            habits_score=habits_score,
            xp_earned=daily_xp,
            calculated_at=datetime.utcnow()
        ).on_conflict_do_update(
            index_elements=["date"],
            set_={
                "life_score": life_score,
                "sleep_score": sleep_score,
                "activity_score": activity_score,
                "worklife_score": worklife_score,
                "habits_score": habits_score,
                "xp_earned": daily_xp,
                "calculated_at": datetime.utcnow()
            }
        )
        await db.execute(stmt)
        await db.commit()

        return DailyScore(
            date=target_date,
            life_score=life_score,
            sleep_score=sleep_score,
            activity_score=activity_score,
            worklife_score=worklife_score,
            habits_score=habits_score,
            xp_earned=daily_xp
        )

    async def get_daily_score(
        self,
        db: AsyncSession,
        target_date: date
    ) -> Optional[DailyScore]:
        """Get daily score from database"""
        result = await db.execute(
            select(DailyScoreDB).where(DailyScoreDB.date == target_date)
        )
        row = result.scalar_one_or_none()
        if row:
            return DailyScore(
                date=row.date,
                life_score=row.life_score or 0,
                sleep_score=row.sleep_score or 0,
                activity_score=row.activity_score or 0,
                worklife_score=row.worklife_score or 0,
                habits_score=row.habits_score or 0,
                xp_earned=row.xp_earned or 0
            )
        return None

    async def get_xp_info(self, db: AsyncSession) -> XPInfo:
        """Get current XP and level information"""
        # Get user profile
        result = await db.execute(select(UserProfileDB).limit(1))
        user = result.scalar_one_or_none()

        total_xp = user.total_xp if user else 0
        level = level_from_xp(total_xp)
        xp_into, xp_needed, progress = xp_progress_in_level(total_xp)

        # Get today's XP
        today_result = await db.execute(
            select(DailyScoreDB.xp_earned).where(DailyScoreDB.date == date.today())
        )
        today_xp = today_result.scalar_one_or_none() or 0

        return XPInfo(
            total_xp=total_xp,
            level=level,
            xp_for_current_level=xp_into,
            xp_for_next_level=xp_needed,
            progress_to_next=progress,
            today_xp=today_xp
        )

    async def add_xp(self, db: AsyncSession, xp_amount: int, event_type: str, details: dict = None):
        """Add XP and log event"""
        # Update user total XP
        await db.execute(
            update(UserProfileDB).values(
                total_xp=UserProfileDB.total_xp + xp_amount,
                level=func.floor(func.sqrt((UserProfileDB.total_xp + xp_amount) / 1000))
            )
        )

        # Log event
        stmt = pg_insert(GamificationEventDB).values(
            time=datetime.utcnow(),
            event_type=event_type,
            xp_earned=xp_amount,
            details=details or {}
        )
        await db.execute(stmt)
        await db.commit()

    async def get_streaks(self, db: AsyncSession) -> dict[str, int]:
        """Get current streak counts"""
        result = await db.execute(select(StreakDB))
        rows = result.scalars().all()
        return {row.streak_type: row.current_count for row in rows}

    async def get_achievements(
        self,
        db: AsyncSession,
        unlocked_only: bool = False
    ) -> list[Achievement]:
        """Get achievements"""
        query = select(AchievementDB)
        if unlocked_only:
            query = query.where(AchievementDB.unlocked_at.isnot(None))

        result = await db.execute(query.order_by(AchievementDB.tier, AchievementDB.name))
        rows = result.scalars().all()

        return [
            Achievement(
                id=row.id,
                code=row.code,
                name=row.name,
                description=row.description,
                tier=row.tier,
                xp_reward=row.xp_reward,
                progress=row.progress,
                target=row.target,
                unlocked_at=row.unlocked_at,
                is_unlocked=row.unlocked_at is not None
            )
            for row in rows
        ]

    async def get_today_response(self, db: AsyncSession) -> TodayResponse:
        """Get complete today response for API"""
        today = date.today()

        # Get or calculate daily score
        daily_score = await self.get_daily_score(db, today)
        if not daily_score:
            daily_score = await self.calculate_daily_score(db, today)

        # Get XP info
        xp_info = await self.get_xp_info(db)

        # Get streaks
        streaks = await self.get_streaks(db)

        # Get recent achievements (last 7 days)
        seven_days_ago = datetime.utcnow() - timedelta(days=7)
        result = await db.execute(
            select(AchievementDB)
            .where(AchievementDB.unlocked_at >= seven_days_ago)
            .order_by(AchievementDB.unlocked_at.desc())
            .limit(5)
        )
        recent_achievements = [
            Achievement(
                id=row.id,
                code=row.code,
                name=row.name,
                description=row.description,
                tier=row.tier,
                xp_reward=row.xp_reward,
                progress=row.progress,
                target=row.target,
                unlocked_at=row.unlocked_at,
                is_unlocked=True
            )
            for row in result.scalars().all()
        ]

        # Generate message
        message = None
        if daily_score.life_score >= 90:
            message = "Outstanding day! Keep up the excellent work!"
        elif daily_score.life_score >= 80:
            message = "Great job today!"
        elif daily_score.life_score >= 70:
            message = "Solid performance. Room for improvement!"
        elif daily_score.life_score < 60:
            message = "Tough day. Tomorrow is a fresh start!"

        return TodayResponse(
            date=today,
            life_score=daily_score.life_score,
            domains={
                "sleep": daily_score.sleep_score,
                "activity": daily_score.activity_score,
                "worklife": daily_score.worklife_score,
                "habits": daily_score.habits_score,
            },
            xp=xp_info,
            streaks=streaks,
            recent_achievements=recent_achievements,
            message=message
        )


# Global service instance
gamification_service = GamificationService()
