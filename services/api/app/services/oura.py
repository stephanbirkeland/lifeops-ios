"""Oura Ring API integration service"""

import httpx
from datetime import date, datetime, timedelta
from typing import Optional, Any
import logging

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, insert, update
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.config import settings
from app.models.health import DailySummaryDB, HealthMetricDB

logger = logging.getLogger(__name__)


class OuraService:
    """Service for interacting with Oura Ring API v2"""

    def __init__(self, access_token: Optional[str] = None):
        self.access_token = access_token or settings.oura_access_token
        self.base_url = settings.oura_api_base_url
        self.client = httpx.AsyncClient(
            base_url=self.base_url,
            headers=self._get_headers(),
            timeout=30.0
        )

    def _get_headers(self) -> dict[str, str]:
        """Get authorization headers"""
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json"
        }

    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()

    def is_configured(self) -> bool:
        """Check if Oura API is configured"""
        return bool(self.access_token)

    # ===========================================
    # API Endpoints
    # ===========================================

    async def get_daily_sleep(
        self,
        start_date: date,
        end_date: Optional[date] = None
    ) -> list[dict[str, Any]]:
        """Get daily sleep data"""
        if not self.is_configured():
            logger.warning("Oura API not configured")
            return []

        params = {"start_date": start_date.isoformat()}
        if end_date:
            params["end_date"] = end_date.isoformat()

        try:
            response = await self.client.get("/usercollection/daily_sleep", params=params)
            response.raise_for_status()
            data = response.json()
            return data.get("data", [])
        except httpx.HTTPStatusError as e:
            logger.error(f"Oura API error (sleep): {e.response.status_code} - {e.response.text}")
            return []
        except Exception as e:
            logger.error(f"Failed to fetch sleep data: {e}")
            return []

    async def get_daily_readiness(
        self,
        start_date: date,
        end_date: Optional[date] = None
    ) -> list[dict[str, Any]]:
        """Get daily readiness data"""
        if not self.is_configured():
            return []

        params = {"start_date": start_date.isoformat()}
        if end_date:
            params["end_date"] = end_date.isoformat()

        try:
            response = await self.client.get("/usercollection/daily_readiness", params=params)
            response.raise_for_status()
            data = response.json()
            return data.get("data", [])
        except httpx.HTTPStatusError as e:
            logger.error(f"Oura API error (readiness): {e.response.status_code}")
            return []
        except Exception as e:
            logger.error(f"Failed to fetch readiness data: {e}")
            return []

    async def get_daily_activity(
        self,
        start_date: date,
        end_date: Optional[date] = None
    ) -> list[dict[str, Any]]:
        """Get daily activity data"""
        if not self.is_configured():
            return []

        params = {"start_date": start_date.isoformat()}
        if end_date:
            params["end_date"] = end_date.isoformat()

        try:
            response = await self.client.get("/usercollection/daily_activity", params=params)
            response.raise_for_status()
            data = response.json()
            return data.get("data", [])
        except httpx.HTTPStatusError as e:
            logger.error(f"Oura API error (activity): {e.response.status_code}")
            return []
        except Exception as e:
            logger.error(f"Failed to fetch activity data: {e}")
            return []

    async def get_sleep_sessions(
        self,
        start_date: date,
        end_date: Optional[date] = None
    ) -> list[dict[str, Any]]:
        """Get detailed sleep sessions"""
        if not self.is_configured():
            return []

        params = {"start_date": start_date.isoformat()}
        if end_date:
            params["end_date"] = end_date.isoformat()

        try:
            response = await self.client.get("/usercollection/sleep", params=params)
            response.raise_for_status()
            data = response.json()
            return data.get("data", [])
        except Exception as e:
            logger.error(f"Failed to fetch sleep sessions: {e}")
            return []

    async def get_heart_rate(
        self,
        start_datetime: datetime,
        end_datetime: Optional[datetime] = None
    ) -> list[dict[str, Any]]:
        """Get heart rate data"""
        if not self.is_configured():
            return []

        params = {"start_datetime": start_datetime.isoformat()}
        if end_datetime:
            params["end_datetime"] = end_datetime.isoformat()

        try:
            response = await self.client.get("/usercollection/heartrate", params=params)
            response.raise_for_status()
            data = response.json()
            return data.get("data", [])
        except Exception as e:
            logger.error(f"Failed to fetch heart rate: {e}")
            return []

    async def get_personal_info(self) -> Optional[dict[str, Any]]:
        """Get user personal info"""
        if not self.is_configured():
            return None

        try:
            response = await self.client.get("/usercollection/personal_info")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Failed to fetch personal info: {e}")
            return None

    # ===========================================
    # Data Sync Methods
    # ===========================================

    async def sync_daily_data(
        self,
        db: AsyncSession,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> dict[str, int]:
        """
        Sync daily sleep, readiness, and activity data to database.
        Returns count of synced records by type.
        """
        if not start_date:
            start_date = date.today() - timedelta(days=7)
        if not end_date:
            end_date = date.today()

        logger.info(f"Syncing Oura data from {start_date} to {end_date}")

        # Fetch all data in parallel
        sleep_data = await self.get_daily_sleep(start_date, end_date)
        readiness_data = await self.get_daily_readiness(start_date, end_date)
        activity_data = await self.get_daily_activity(start_date, end_date)

        # Index by date for easy lookup
        sleep_by_date = {d["day"]: d for d in sleep_data}
        readiness_by_date = {d["day"]: d for d in readiness_data}
        activity_by_date = {d["day"]: d for d in activity_data}

        # Get all dates
        all_dates = set(sleep_by_date.keys()) | set(readiness_by_date.keys()) | set(activity_by_date.keys())

        synced = {"sleep": 0, "readiness": 0, "activity": 0}

        for date_str in all_dates:
            day = date.fromisoformat(date_str)
            sleep = sleep_by_date.get(date_str, {})
            readiness = readiness_by_date.get(date_str, {})
            activity = activity_by_date.get(date_str, {})

            # Upsert daily summary
            stmt = pg_insert(DailySummaryDB).values(
                date=day,
                sleep_score=sleep.get("score"),
                readiness_score=readiness.get("score"),
                activity_score=activity.get("score"),
                sleep_data=sleep,
                readiness_data=readiness,
                activity_data=activity,
                synced_at=datetime.utcnow()
            ).on_conflict_do_update(
                index_elements=["date"],
                set_={
                    "sleep_score": sleep.get("score"),
                    "readiness_score": readiness.get("score"),
                    "activity_score": activity.get("score"),
                    "sleep_data": sleep,
                    "readiness_data": readiness,
                    "activity_data": activity,
                    "synced_at": datetime.utcnow()
                }
            )
            await db.execute(stmt)

            if sleep.get("score"):
                synced["sleep"] += 1
            if readiness.get("score"):
                synced["readiness"] += 1
            if activity.get("score"):
                synced["activity"] += 1

        await db.commit()
        logger.info(f"Synced: {synced}")
        return synced

    async def get_latest_summary(
        self,
        db: AsyncSession,
        target_date: Optional[date] = None
    ) -> Optional[dict[str, Any]]:
        """Get latest daily summary from database"""
        if not target_date:
            target_date = date.today()

        result = await db.execute(
            select(DailySummaryDB).where(DailySummaryDB.date == target_date)
        )
        row = result.scalar_one_or_none()

        if row:
            return {
                "date": row.date,
                "sleep_score": row.sleep_score,
                "readiness_score": row.readiness_score,
                "activity_score": row.activity_score,
                "sleep_data": row.sleep_data,
                "readiness_data": row.readiness_data,
                "activity_data": row.activity_data,
                "synced_at": row.synced_at
            }
        return None

    async def get_summaries_range(
        self,
        db: AsyncSession,
        start_date: date,
        end_date: date
    ) -> list[dict[str, Any]]:
        """Get daily summaries for a date range"""
        result = await db.execute(
            select(DailySummaryDB)
            .where(DailySummaryDB.date >= start_date)
            .where(DailySummaryDB.date <= end_date)
            .order_by(DailySummaryDB.date.desc())
        )
        rows = result.scalars().all()

        return [
            {
                "date": row.date,
                "sleep_score": row.sleep_score,
                "readiness_score": row.readiness_score,
                "activity_score": row.activity_score,
            }
            for row in rows
        ]


# Global service instance
oura_service = OuraService()
