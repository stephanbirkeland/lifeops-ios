"""Timeline API endpoints - rolling task/event feed"""

from datetime import date, time
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.timeline import (
    TimeAnchor, TimelineItem, TimelineItemCreate,
    TimelineFeed, PostponeRequest, PostponeResponse,
    CompleteRequest, CompleteResponse, PostponeTarget
)
from app.services.timeline import TimelineService

router = APIRouter(prefix="/timeline", tags=["timeline"])


# ===========================================
# Feed Endpoints
# ===========================================

@router.get("", response_model=TimelineFeed)
async def get_timeline(
    hours: int = Query(4, ge=1, le=24, description="Hours to show ahead"),
    expand: bool = Query(False, description="Show full day"),
    for_date: Optional[date] = Query(None, description="Date to show (default: today)"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get the rolling timeline feed.

    Shows items that are:
    - Currently active (within their time window)
    - Upcoming in the next N hours
    - Overdue (past their window but not completed)

    Use `expand=true` to see the full day.
    """
    service = TimelineService(db)
    return await service.get_feed(
        window_hours=hours,
        for_date=for_date,
        expand=expand
    )


@router.get("/day", response_model=TimelineFeed)
async def get_full_day(
    for_date: Optional[date] = Query(None, description="Date to show"),
    db: AsyncSession = Depends(get_db)
):
    """Get the full day timeline"""
    service = TimelineService(db)
    return await service.get_feed(
        window_hours=24,
        for_date=for_date,
        expand=True
    )


# ===========================================
# Item Actions
# ===========================================

@router.post("/{item_code}/complete", response_model=CompleteResponse)
async def complete_item(
    item_code: str,
    request: CompleteRequest = CompleteRequest(),
    for_date: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Mark a timeline item as completed.

    Grants XP to Stats Service and updates streak.
    """
    service = TimelineService(db)
    try:
        return await service.complete_item(item_code, request, for_date)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{item_code}/postpone", response_model=PostponeResponse)
async def postpone_item(
    item_code: str,
    request: PostponeRequest,
    for_date: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Postpone a timeline item.

    Smart targets:
    - `lunch` - Move to lunch time
    - `afternoon` - Move to afternoon
    - `after_work` - Move to after work
    - `evening` - Move to evening
    - `tonight` - Move to night
    - `tomorrow` - Move to same time tomorrow
    - `tomorrow_morning` - Move to tomorrow morning
    - `next_week` - Move to same time next week
    - `custom` - Use custom_date and custom_time
    """
    service = TimelineService(db)
    try:
        return await service.postpone_item(item_code, request, for_date)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{item_code}/skip")
async def skip_item(
    item_code: str,
    reason: Optional[str] = Query(None),
    for_date: Optional[date] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """Skip a timeline item for today"""
    service = TimelineService(db)
    try:
        return await service.skip_item(item_code, reason, for_date)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ===========================================
# Item Management
# ===========================================

@router.get("/items", response_model=list[TimelineItem])
async def list_items(
    active_only: bool = Query(True),
    db: AsyncSession = Depends(get_db)
):
    """List all timeline items"""
    service = TimelineService(db)
    return await service.list_items(active_only)


@router.get("/items/{item_code}", response_model=TimelineItem)
async def get_item(
    item_code: str,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific timeline item"""
    service = TimelineService(db)
    item = await service.get_item(item_code)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.post("/items", response_model=TimelineItem, status_code=201)
async def create_item(
    data: TimelineItemCreate,
    db: AsyncSession = Depends(get_db)
):
    """Create a new timeline item"""
    service = TimelineService(db)
    try:
        return await service.create_item(data)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/items/{item_code}", response_model=TimelineItem)
async def update_item(
    item_code: str,
    updates: dict,
    db: AsyncSession = Depends(get_db)
):
    """Update a timeline item"""
    service = TimelineService(db)
    item = await service.update_item(item_code, updates)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.delete("/items/{item_code}")
async def delete_item(
    item_code: str,
    db: AsyncSession = Depends(get_db)
):
    """Delete (deactivate) a timeline item"""
    service = TimelineService(db)
    if not await service.delete_item(item_code):
        raise HTTPException(status_code=404, detail="Item not found")
    return {"success": True, "message": f"Item {item_code} deactivated"}


# ===========================================
# Time Anchors
# ===========================================

@router.get("/anchors", response_model=list[TimeAnchor])
async def get_anchors(db: AsyncSession = Depends(get_db)):
    """
    Get all time anchors.

    Time anchors are reference points like "lunch", "after_work" that
    can be customized per user.
    """
    service = TimelineService(db)
    return await service.get_anchors()


@router.patch("/anchors/{code}")
async def update_anchor(
    code: str,
    new_time: time,
    db: AsyncSession = Depends(get_db)
):
    """
    Update a time anchor.

    Example: Set lunch to 12:30
    """
    service = TimelineService(db)
    anchor = await service.update_anchor(code, new_time)
    if not anchor:
        raise HTTPException(status_code=404, detail="Anchor not found")
    return anchor


# ===========================================
# Quick Actions
# ===========================================

@router.get("/postpone-options")
async def get_postpone_options():
    """Get available postpone targets"""
    return {
        "targets": [
            {"code": "lunch", "name": "Lunch", "description": "Move to lunch time"},
            {"code": "afternoon", "name": "Afternoon", "description": "Move to early afternoon"},
            {"code": "after_work", "name": "After Work", "description": "Move to end of work day"},
            {"code": "evening", "name": "Evening", "description": "Move to evening"},
            {"code": "tonight", "name": "Tonight", "description": "Move to night time"},
            {"code": "tomorrow", "name": "Tomorrow", "description": "Move to same time tomorrow"},
            {"code": "tomorrow_morning", "name": "Tomorrow Morning", "description": "Move to tomorrow morning"},
            {"code": "next_week", "name": "Next Week", "description": "Move to same time next week"},
            {"code": "custom", "name": "Custom", "description": "Set specific date/time"}
        ]
    }
