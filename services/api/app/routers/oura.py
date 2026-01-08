"""Oura Ring API endpoints"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from datetime import date, timedelta
from typing import Optional, Any

from app.core.database import get_db
from app.services.oura import oura_service

router = APIRouter(prefix="/oura", tags=["Oura"])


class SyncResponse(BaseModel):
    """Response for sync operation"""
    success: bool
    message: str
    synced: dict[str, int]


class DailySummaryResponse(BaseModel):
    """Daily summary response"""
    date: date
    sleep_score: Optional[int]
    readiness_score: Optional[int]
    activity_score: Optional[int]
    sleep_data: dict[str, Any] = {}
    readiness_data: dict[str, Any] = {}
    activity_data: dict[str, Any] = {}


@router.get("/status")
async def oura_status():
    """Check Oura API configuration status"""
    is_configured = oura_service.is_configured()

    if is_configured:
        # Try to fetch personal info to verify token
        info = await oura_service.get_personal_info()
        return {
            "configured": True,
            "connected": info is not None,
            "user_info": info
        }

    return {
        "configured": False,
        "connected": False,
        "message": "Set OURA_ACCESS_TOKEN environment variable"
    }


@router.post("/sync", response_model=SyncResponse)
async def sync_oura_data(
    start_date: Optional[date] = Query(default=None, description="Start date for sync"),
    end_date: Optional[date] = Query(default=None, description="End date for sync"),
    db: AsyncSession = Depends(get_db)
):
    """
    Sync Oura data to local database.
    Defaults to last 7 days if no dates specified.
    """
    if not oura_service.is_configured():
        raise HTTPException(
            status_code=400,
            detail="Oura API not configured. Set OURA_ACCESS_TOKEN."
        )

    if not start_date:
        start_date = date.today() - timedelta(days=7)
    if not end_date:
        end_date = date.today()

    try:
        synced = await oura_service.sync_daily_data(db, start_date, end_date)
        return SyncResponse(
            success=True,
            message=f"Synced data from {start_date} to {end_date}",
            synced=synced
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/today", response_model=Optional[DailySummaryResponse])
async def get_today(db: AsyncSession = Depends(get_db)):
    """Get today's Oura data"""
    summary = await oura_service.get_latest_summary(db, date.today())

    if not summary:
        return None

    return DailySummaryResponse(**summary)


@router.get("/summary/{target_date}", response_model=Optional[DailySummaryResponse])
async def get_summary(
    target_date: date,
    db: AsyncSession = Depends(get_db)
):
    """Get Oura data for a specific date"""
    summary = await oura_service.get_latest_summary(db, target_date)

    if not summary:
        raise HTTPException(status_code=404, detail=f"No data for {target_date}")

    return DailySummaryResponse(**summary)


@router.get("/history")
async def get_history(
    start_date: date = Query(..., description="Start date"),
    end_date: date = Query(default=None, description="End date (defaults to today)"),
    db: AsyncSession = Depends(get_db)
):
    """Get Oura data history for date range"""
    if not end_date:
        end_date = date.today()

    summaries = await oura_service.get_summaries_range(db, start_date, end_date)

    return {
        "start_date": start_date,
        "end_date": end_date,
        "count": len(summaries),
        "data": summaries
    }


@router.get("/sleep/{target_date}")
async def get_sleep_details(
    target_date: date,
    db: AsyncSession = Depends(get_db)
):
    """Get detailed sleep data for a specific date"""
    summary = await oura_service.get_latest_summary(db, target_date)

    if not summary:
        raise HTTPException(status_code=404, detail=f"No data for {target_date}")

    sleep_data = summary.get("sleep_data", {})

    return {
        "date": target_date,
        "score": sleep_data.get("score"),
        "contributors": sleep_data.get("contributors", {}),
        "total_sleep": sleep_data.get("total_sleep_duration"),
        "rem_sleep": sleep_data.get("rem_sleep_duration"),
        "deep_sleep": sleep_data.get("deep_sleep_duration"),
        "light_sleep": sleep_data.get("light_sleep_duration"),
        "efficiency": sleep_data.get("efficiency"),
        "raw_data": sleep_data
    }
