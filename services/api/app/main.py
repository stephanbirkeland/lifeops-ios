"""LifeOps API - Main Application Entry Point"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

from app.core.config import settings
from app.core.database import init_db, close_db
from app.routers import health_router, oura_router, gamification_router, user_router, timeline_router

# Configure logging
logging.basicConfig(
    level=logging.INFO if settings.environment == "production" else logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - startup and shutdown"""
    # Startup
    logger.info(f"Starting LifeOps API ({settings.environment})")
    await init_db()
    logger.info("Database initialized")

    yield

    # Shutdown
    logger.info("Shutting down LifeOps API")
    await close_db()


# Create FastAPI application
app = FastAPI(
    title="LifeOps API",
    description="""
    Personal Life Management System API

    ## Features

    - **Timeline**: Rolling task feed that moves with your day
    - **Oura Integration**: Sync sleep, readiness, and activity data
    - **Gamification**: Life Score, XP, streaks, and achievements
    - **User Profile**: Goals and settings management

    ## Quick Start

    1. Get your timeline: `GET /timeline`
    2. Get your Life Score: `GET /api/today`
    3. Sync Oura data: `POST /oura/sync`
    4. Complete a task: `POST /timeline/{code}/complete`
    """,
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",      # Next.js dev
        "http://localhost:8080",      # Other local
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health_router)
app.include_router(oura_router)
app.include_router(gamification_router)
app.include_router(user_router)
app.include_router(timeline_router)


# Additional middleware for request logging (development)
if settings.environment == "development":
    from fastapi import Request
    import time

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        start_time = time.time()
        response = await call_next(request)
        duration = time.time() - start_time
        logger.debug(
            f"{request.method} {request.url.path} - {response.status_code} ({duration:.3f}s)"
        )
        return response


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.environment == "development"
    )
