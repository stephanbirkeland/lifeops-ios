"""Gamification API endpoints"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import date, timedelta
from typing import Optional

from app.core.database import get_db
from app.services.gamification import gamification_service
from app.models.gamification import (
    TodayResponse, DailyScore, XPInfo, Achievement
)

router = APIRouter(prefix="/api", tags=["Gamification"])


@router.get("/today", response_model=TodayResponse)
async def get_today(db: AsyncSession = Depends(get_db)):
    """
    Get today's Life Score, domains, XP, streaks, and recent achievements.
    This is the main endpoint for the mobile app dashboard.
    """
    return await gamification_service.get_today_response(db)


@router.get("/score/{target_date}", response_model=DailyScore)
async def get_score(
    target_date: date,
    recalculate: bool = Query(default=False, description="Force recalculation"),
    db: AsyncSession = Depends(get_db)
):
    """Get Life Score for a specific date"""
    if recalculate:
        return await gamification_service.calculate_daily_score(db, target_date)

    score = await gamification_service.get_daily_score(db, target_date)
    if not score:
        # Calculate if not exists
        score = await gamification_service.calculate_daily_score(db, target_date)

    return score


@router.post("/score/{target_date}/calculate", response_model=DailyScore)
async def calculate_score(
    target_date: date,
    habits_completed: int = Query(default=0),
    habits_total: int = Query(default=5),
    screen_hours: float = Query(default=3.0),
    work_hours: float = Query(default=8.0),
    work_cutoff_hour: int = Query(default=17),
    db: AsyncSession = Depends(get_db)
):
    """
    Calculate and store Life Score with custom input data.
    Use this to log habits and work data not tracked automatically.
    """
    return await gamification_service.calculate_daily_score(
        db,
        target_date,
        habits_data={
            "completed": habits_completed,
            "total": habits_total,
            "screen_hours": screen_hours
        },
        work_data={
            "hours": work_hours,
            "cutoff_hour": work_cutoff_hour
        }
    )


@router.get("/history")
async def get_score_history(
    days: int = Query(default=30, le=365, description="Number of days"),
    db: AsyncSession = Depends(get_db)
):
    """Get Life Score history for the last N days"""
    from sqlalchemy import select
    from app.models.gamification import DailyScoreDB

    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    result = await db.execute(
        select(DailyScoreDB)
        .where(DailyScoreDB.date >= start_date)
        .order_by(DailyScoreDB.date.desc())
    )
    rows = result.scalars().all()

    return {
        "start_date": start_date,
        "end_date": end_date,
        "count": len(rows),
        "average_life_score": sum(r.life_score or 0 for r in rows) / len(rows) if rows else 0,
        "data": [
            {
                "date": r.date,
                "life_score": r.life_score,
                "sleep": r.sleep_score,
                "activity": r.activity_score,
                "worklife": r.worklife_score,
                "habits": r.habits_score,
                "xp": r.xp_earned
            }
            for r in rows
        ]
    }


@router.get("/xp", response_model=XPInfo)
async def get_xp(db: AsyncSession = Depends(get_db)):
    """Get current XP and level information"""
    return await gamification_service.get_xp_info(db)


@router.get("/streaks")
async def get_streaks(db: AsyncSession = Depends(get_db)):
    """Get all current streaks"""
    streaks = await gamification_service.get_streaks(db)
    return {"streaks": streaks}


@router.get("/achievements", response_model=list[Achievement])
async def get_achievements(
    unlocked_only: bool = Query(default=False),
    db: AsyncSession = Depends(get_db)
):
    """Get all achievements"""
    return await gamification_service.get_achievements(db, unlocked_only)


@router.get("/achievements/recent", response_model=list[Achievement])
async def get_recent_achievements(
    days: int = Query(default=7, le=30),
    db: AsyncSession = Depends(get_db)
):
    """Get recently unlocked achievements"""
    from sqlalchemy import select
    from datetime import datetime
    from app.models.gamification import AchievementDB

    cutoff = datetime.utcnow() - timedelta(days=days)
    result = await db.execute(
        select(AchievementDB)
        .where(AchievementDB.unlocked_at >= cutoff)
        .order_by(AchievementDB.unlocked_at.desc())
    )

    return [
        Achievement(
            id=r.id,
            code=r.code,
            name=r.name,
            description=r.description,
            tier=r.tier,
            xp_reward=r.xp_reward,
            progress=r.progress,
            target=r.target,
            unlocked_at=r.unlocked_at,
            is_unlocked=True
        )
        for r in result.scalars().all()
    ]


@router.get("/stats")
async def get_stats(db: AsyncSession = Depends(get_db)):
    """Get overall statistics"""
    from sqlalchemy import select, func
    from app.models.gamification import DailyScoreDB, AchievementDB
    from app.models.user import UserProfileDB

    # Get user profile
    user_result = await db.execute(select(UserProfileDB).limit(1))
    user = user_result.scalar_one_or_none()

    # Get score statistics
    stats_result = await db.execute(
        select(
            func.count(DailyScoreDB.date).label("total_days"),
            func.avg(DailyScoreDB.life_score).label("avg_life_score"),
            func.max(DailyScoreDB.life_score).label("best_life_score"),
            func.sum(DailyScoreDB.xp_earned).label("total_xp_from_scores")
        )
    )
    stats = stats_result.one()

    # Get achievement counts
    achievement_result = await db.execute(
        select(func.count(AchievementDB.id))
        .where(AchievementDB.unlocked_at.isnot(None))
    )
    unlocked_count = achievement_result.scalar() or 0

    total_achievement_result = await db.execute(
        select(func.count(AchievementDB.id))
    )
    total_achievements = total_achievement_result.scalar() or 0

    return {
        "total_xp": user.total_xp if user else 0,
        "level": user.level if user else 1,
        "days_tracked": stats.total_days or 0,
        "average_life_score": round(stats.avg_life_score or 0, 1),
        "best_life_score": stats.best_life_score or 0,
        "achievements_unlocked": unlocked_count,
        "achievements_total": total_achievements,
        "achievement_progress": round(
            (unlocked_count / total_achievements * 100) if total_achievements > 0 else 0, 1
        )
    }
