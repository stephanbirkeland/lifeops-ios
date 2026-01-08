"""LifeOps API - Main Application Entry Point"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import init_db, close_db
from app.core.logging import setup_logging, get_logger, set_correlation_id, get_correlation_id
from app.core.error_handlers import register_exception_handlers
from app.routers import health_router, oura_router, gamification_router, user_router, timeline_router
from app.routers.auth import router as auth_router

# Configure logging
setup_logging()
logger = get_logger(__name__)


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

    - **Authentication**: JWT-based auth with register, login, and token refresh
    - **Timeline**: Rolling task feed that moves with your day
    - **Oura Integration**: Sync sleep, readiness, and activity data
    - **Gamification**: Life Score, XP, streaks, and achievements
    - **User Profile**: Goals and settings management

    ## Quick Start

    1. Register: `POST /auth/register`
    2. Login: `POST /auth/login` (get access token)
    3. Get your timeline: `GET /timeline` (with Bearer token)
    4. Get your Life Score: `GET /api/today`
    5. Sync Oura data: `POST /oura/sync`
    6. Complete a task: `POST /timeline/{code}/complete`

    ## Authentication

    Most endpoints require authentication. Include your access token in requests:

    ```
    Authorization: Bearer <your_access_token>
    ```
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

# Register exception handlers
register_exception_handlers(app)

# Include routers
app.include_router(auth_router)  # Authentication first
app.include_router(health_router)
app.include_router(oura_router)
app.include_router(gamification_router)
app.include_router(user_router)
app.include_router(timeline_router)


# Correlation ID middleware - must be added after CORS
@app.middleware("http")
async def correlation_id_middleware(request: Request, call_next):
    """Add correlation ID to each request for distributed tracing."""
    # Check for existing correlation ID in headers
    correlation_id = request.headers.get("X-Correlation-ID")
    correlation_id = set_correlation_id(correlation_id)

    response = await call_next(request)

    # Add correlation ID to response headers
    response.headers["X-Correlation-ID"] = correlation_id
    return response


# Additional middleware for request logging (development)
if settings.environment == "development":
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
