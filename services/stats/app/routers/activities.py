"""Activity logging endpoints"""

from uuid import UUID
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.activity import (
    Activity, ActivityCreate, ActivityResponse,
    ActivityBatchCreate, ActivityBatchResponse
)
from app.services.activity import ActivityService

router = APIRouter(prefix="/activities", tags=["activities"])


@router.post("", response_model=ActivityResponse, status_code=201)
async def log_activity(
    data: ActivityCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Log an activity and grant XP.

    Activity types are mapped to XP grants automatically.
    Use custom_xp to override the calculated XP.
    """
    service = ActivityService(db)
    try:
        return await service.log_activity(data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/batch", response_model=ActivityBatchResponse)
async def log_activities_batch(
    data: ActivityBatchCreate,
    db: AsyncSession = Depends(get_db)
):
    """Log multiple activities at once"""
    service = ActivityService(db)
    return await service.log_batch(data.activities)


@router.get("/{activity_id}", response_model=Activity)
async def get_activity(
    activity_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific activity by ID"""
    service = ActivityService(db)
    activity = await service.get_activity(activity_id)
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    return activity


@router.get("/character/{character_id}", response_model=list[Activity])
async def get_character_activities(
    character_id: UUID,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """Get recent activities for a character"""
    service = ActivityService(db)
    return await service.get_recent_activities(character_id, limit, offset)


@router.get("/character/{character_id}/range", response_model=list[Activity])
async def get_character_activities_range(
    character_id: UUID,
    start_date: datetime,
    end_date: datetime,
    db: AsyncSession = Depends(get_db)
):
    """Get activities within a date range"""
    service = ActivityService(db)
    return await service.get_activities_by_date_range(
        character_id, start_date, end_date
    )


@router.get("/types")
async def get_activity_types():
    """Get available activity types and their XP mappings"""
    from app.core.config import settings
    return {
        "activity_types": list(settings.ACTIVITY_XP_MAPPING.keys()),
        "xp_mapping": settings.ACTIVITY_XP_MAPPING
    }
