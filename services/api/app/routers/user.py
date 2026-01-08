"""User profile and settings endpoints"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db
from app.models.user import UserProfile, UserProfileUpdate, UserProfileDB, UserGoals

router = APIRouter(prefix="/user", tags=["User"])


@router.get("/profile", response_model=UserProfile)
async def get_profile(db: AsyncSession = Depends(get_db)):
    """Get user profile"""
    result = await db.execute(select(UserProfileDB).limit(1))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    return UserProfile.model_validate(user)


@router.patch("/profile", response_model=UserProfile)
async def update_profile(
    updates: UserProfileUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Update user profile"""
    result = await db.execute(select(UserProfileDB).limit(1))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    # Build update dict with only non-None values
    update_data = updates.model_dump(exclude_unset=True, exclude_none=True)

    if update_data:
        await db.execute(
            update(UserProfileDB)
            .where(UserProfileDB.id == user.id)
            .values(**update_data)
        )
        await db.commit()

        # Refresh
        result = await db.execute(
            select(UserProfileDB).where(UserProfileDB.id == user.id)
        )
        user = result.scalar_one()

    return UserProfile.model_validate(user)


@router.get("/goals", response_model=UserGoals)
async def get_goals(db: AsyncSession = Depends(get_db)):
    """Get user goals"""
    result = await db.execute(select(UserProfileDB).limit(1))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    return UserGoals(
        target_wake_time=user.target_wake_time,
        target_bedtime=user.target_bedtime,
        target_screen_hours=user.target_screen_hours,
        target_gym_sessions=user.target_gym_sessions
    )


@router.patch("/goals", response_model=UserGoals)
async def update_goals(
    goals: UserGoals,
    db: AsyncSession = Depends(get_db)
):
    """Update user goals"""
    result = await db.execute(select(UserProfileDB).limit(1))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    await db.execute(
        update(UserProfileDB)
        .where(UserProfileDB.id == user.id)
        .values(
            target_wake_time=goals.target_wake_time,
            target_bedtime=goals.target_bedtime,
            target_screen_hours=goals.target_screen_hours,
            target_gym_sessions=goals.target_gym_sessions
        )
    )
    await db.commit()

    return goals


@router.get("/settings")
async def get_settings(db: AsyncSession = Depends(get_db)):
    """Get user settings"""
    result = await db.execute(select(UserProfileDB).limit(1))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    return user.settings or {}


@router.patch("/settings")
async def update_settings(
    settings: dict,
    db: AsyncSession = Depends(get_db)
):
    """Update user settings (merges with existing)"""
    result = await db.execute(select(UserProfileDB).limit(1))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    # Merge settings
    current_settings = user.settings or {}
    current_settings.update(settings)

    await db.execute(
        update(UserProfileDB)
        .where(UserProfileDB.id == user.id)
        .values(settings=current_settings)
    )
    await db.commit()

    return current_settings
