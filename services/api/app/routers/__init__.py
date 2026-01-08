"""API Routers"""

from app.routers.health import router as health_router
from app.routers.oura import router as oura_router
from app.routers.gamification import router as gamification_router
from app.routers.user import router as user_router
from app.routers.timeline import router as timeline_router
from app.routers.auth import router as auth_router

__all__ = [
    "health_router",
    "oura_router",
    "gamification_router",
    "user_router",
    "timeline_router",
    "auth_router",
]
