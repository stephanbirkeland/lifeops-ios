"""Health check and system status endpoints"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from datetime import datetime

from app.core.database import get_db
from app.core.config import settings
from app.services.oura import oura_service

router = APIRouter(tags=["Health"])


class HealthStatus(BaseModel):
    """Health check response"""
    status: str
    timestamp: datetime
    version: str
    environment: str
    services: dict[str, str]


@router.get("/health", response_model=HealthStatus)
async def health_check(db: AsyncSession = Depends(get_db)) -> HealthStatus:
    """
    Health check endpoint.
    Verifies database connection and service availability.
    """
    services = {}

    # Check database
    try:
        await db.execute(text("SELECT 1"))
        services["database"] = "healthy"
    except Exception as e:
        services["database"] = f"unhealthy: {str(e)}"

    # Check Oura API configuration
    if oura_service.is_configured():
        services["oura"] = "configured"
    else:
        services["oura"] = "not_configured"

    # Overall status
    all_healthy = all(
        v in ("healthy", "configured", "not_configured")
        for v in services.values()
    )

    return HealthStatus(
        status="healthy" if all_healthy else "degraded",
        timestamp=datetime.utcnow(),
        version="0.1.0",
        environment=settings.environment,
        services=services
    )


@router.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "LifeOps API",
        "version": "0.1.0",
        "docs": "/docs",
        "health": "/health"
    }
