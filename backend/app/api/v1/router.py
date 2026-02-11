"""Main API router combining all endpoint routers."""

from fastapi import APIRouter

from app.api.v1 import health_data, tracking, analysis, podcast, sound_healing, sync, user

api_router = APIRouter()

# Include all routers
api_router.include_router(
    health_data.router,
    prefix="/health",
    tags=["Health Data"],
)

api_router.include_router(
    tracking.router,
    prefix="/tracking",
    tags=["Manual Tracking"],
)

api_router.include_router(
    analysis.router,
    prefix="/analysis",
    tags=["AI Analysis"],
)

api_router.include_router(
    podcast.router,
    prefix="/podcast",
    tags=["Podcast"],
)

api_router.include_router(
    sound_healing.router,
    prefix="/sound",
    tags=["Sound Healing"],
)

api_router.include_router(
    sync.router,
    prefix="/sync",
    tags=["iOS Sync"],
)

api_router.include_router(
    user.router,
    prefix="/user",
    tags=["User"],
)
