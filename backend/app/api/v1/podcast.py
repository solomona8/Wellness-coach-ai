"""Podcast endpoints."""

from datetime import date, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from fastapi.responses import StreamingResponse
import structlog

from app.models.audio import PodcastResponse, PodcastListResponse
from app.core.auth import get_current_user
from app.services.supabase import SupabaseService, get_supabase_service
from app.services.podcast_service import PodcastService, get_podcast_service
from app.services.storage import StorageService, get_storage_service

router = APIRouter()
logger = structlog.get_logger()


@router.get("/today", response_model=PodcastResponse)
async def get_todays_podcast(
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get today's podcast if available."""
    today = date.today()
    podcast = await supabase.get_podcast_by_date(
        user_id=user["id"],
        podcast_date=today,
    )
    if not podcast:
        raise HTTPException(
            status_code=404,
            detail="Today's podcast is not ready yet",
        )
    return podcast


@router.get("/history", response_model=PodcastListResponse)
async def get_podcast_history(
    page: int = Query(1, ge=1),
    per_page: int = Query(10, le=50),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get podcast history with pagination."""
    offset = (page - 1) * per_page
    podcasts = await supabase.get_podcasts(
        user_id=user["id"],
        limit=per_page,
        offset=offset,
    )
    total = await supabase.count_podcasts(user_id=user["id"])

    return PodcastListResponse(
        podcasts=podcasts,
        total=total,
        page=page,
        per_page=per_page,
    )


@router.post("/generate", response_model=PodcastResponse)
async def generate_podcast(
    podcast_date: Optional[date] = None,
    background_tasks: BackgroundTasks = None,
    user: dict = Depends(get_current_user),
    podcast_service: PodcastService = Depends(get_podcast_service),
):
    """Manually trigger podcast generation."""
    target_date = podcast_date or date.today()

    try:
        podcast = await podcast_service.generate_daily_podcast(
            user_id=user["id"],
            podcast_date=target_date,
        )
        logger.info(
            "Generated podcast",
            user_id=user["id"],
            date=str(target_date),
        )
        return podcast
    except Exception as e:
        logger.error("Failed to generate podcast", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to generate podcast",
        )


@router.post("/listened/{podcast_id}")
async def mark_as_listened(
    podcast_id: str,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Mark a podcast as listened."""
    result = await supabase.mark_podcast_listened(
        user_id=user["id"],
        podcast_id=podcast_id,
    )
    if not result:
        raise HTTPException(
            status_code=404,
            detail="Podcast not found",
        )
    return {"status": "marked as listened"}


@router.get("/stream/{podcast_id}")
async def stream_podcast(
    podcast_id: str,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
    storage: StorageService = Depends(get_storage_service),
):
    """Stream a podcast audio file."""
    podcast = await supabase.get_podcast_by_id(
        user_id=user["id"],
        podcast_id=podcast_id,
    )
    if not podcast:
        raise HTTPException(
            status_code=404,
            detail="Podcast not found",
        )

    # Get the audio stream
    audio_stream = await storage.get_audio_stream(podcast["audio_url"])

    return StreamingResponse(
        audio_stream,
        media_type="audio/mpeg",
        headers={
            "Content-Disposition": f"inline; filename=podcast_{podcast_id}.mp3",
        },
    )


@router.get("/{podcast_id}", response_model=PodcastResponse)
async def get_podcast_by_id(
    podcast_id: str,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get a specific podcast by ID."""
    podcast = await supabase.get_podcast_by_id(
        user_id=user["id"],
        podcast_id=podcast_id,
    )
    if not podcast:
        raise HTTPException(
            status_code=404,
            detail="Podcast not found",
        )
    return podcast
