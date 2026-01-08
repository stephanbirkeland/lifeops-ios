"""Stats Service API routers"""

from app.routers.characters import router as characters_router
from app.routers.stats import router as stats_router
from app.routers.tree import router as tree_router
from app.routers.activities import router as activities_router

__all__ = ["characters_router", "stats_router", "tree_router", "activities_router"]
