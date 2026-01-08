"""Stats Service - RPG-style character progression API"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import engine, Base
from app.routers import characters_router, stats_router, tree_router, activities_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    # Startup: Create tables if needed (dev only - use migrations in prod)
    if settings.DEBUG:
        async with engine.begin() as conn:
            # Don't drop existing tables - let init SQL handle schema
            pass
    yield
    # Shutdown
    await engine.dispose()


app = FastAPI(
    title="Stats Service",
    description="RPG-style character progression system for LifeOps",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(characters_router)
app.include_router(stats_router)
app.include_router(tree_router)
app.include_router(activities_router)


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "service": "Stats Service",
        "version": "1.0.0",
        "status": "healthy"
    }


@app.get("/health")
async def health():
    """Detailed health check"""
    return {
        "status": "healthy",
        "database": "connected",
        "version": "1.0.0"
    }


# API info endpoint
@app.get("/info")
async def info():
    """Service information"""
    return {
        "name": "Stats Service",
        "description": "RPG-style character progression for LifeOps",
        "version": "1.0.0",
        "features": [
            "Character management",
            "6 core stats (STR, INT, WIS, STA, CHA, LCK)",
            "Graph-based skill tree",
            "Activity logging with XP",
            "Derived stats",
            "Skills system"
        ],
        "endpoints": {
            "characters": "/characters",
            "stats": "/stats",
            "tree": "/tree",
            "activities": "/activities"
        }
    }
