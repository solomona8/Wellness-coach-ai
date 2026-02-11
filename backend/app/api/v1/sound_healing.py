"""Sound healing endpoints."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
import structlog

from app.models.audio import (
    SoundHealingTrack,
    SoundRecommendation,
    DynamicSoundRequest,
    DynamicSoundResponse,
    SoundSessionCreate,
    SoundSessionResponse,
    SoundCategory,
    TargetState,
)
from app.core.auth import get_current_user
from app.services.supabase import SupabaseService, get_supabase_service
from app.services.sound_service import SoundHealingService, get_sound_service
from app.services.storage import StorageService, get_storage_service

router = APIRouter()
logger = structlog.get_logger()


@router.get("/library", response_model=list[SoundHealingTrack])
async def get_sound_library(
    category: Optional[SoundCategory] = None,
    target_state: Optional[TargetState] = None,
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Browse the sound healing library."""
    tracks = await supabase.get_sound_tracks(
        category=category,
        target_state=target_state,
        limit=limit,
        offset=offset,
    )
    return tracks


@router.get("/recommendations", response_model=list[SoundRecommendation])
async def get_recommendations(
    current_hrv: Optional[float] = None,
    current_stress: Optional[int] = Query(None, ge=1, le=10),
    time_of_day: Optional[str] = Query(None, pattern="^(morning|afternoon|evening|night)$"),
    user: dict = Depends(get_current_user),
    sound_service: SoundHealingService = Depends(get_sound_service),
):
    """Get personalized sound healing recommendations."""
    current_state = {
        "current_hrv": current_hrv,
        "current_stress": current_stress,
        "time_of_day": time_of_day,
    }

    recommendations = await sound_service.get_recommendations(
        user_id=user["id"],
        current_state=current_state,
    )
    return recommendations


@router.post("/generate", response_model=DynamicSoundResponse)
async def generate_dynamic_sound(
    request: DynamicSoundRequest,
    user: dict = Depends(get_current_user),
    sound_service: SoundHealingService = Depends(get_sound_service),
):
    """Generate dynamic sound healing based on current state."""
    try:
        result = await sound_service.generate_dynamic_sound(
            user_id=user["id"],
            params=request.model_dump(),
        )
        logger.info(
            "Generated dynamic sound",
            user_id=user["id"],
            target_state=request.target_state,
            duration=request.duration_seconds,
        )
        return result
    except Exception as e:
        logger.error("Failed to generate dynamic sound", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to generate sound",
        )


@router.post("/session/start", response_model=dict)
async def start_sound_session(
    track_id: Optional[str] = None,
    is_dynamic: bool = False,
    dynamic_params: Optional[dict] = None,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Start a sound healing session."""
    session_id = await supabase.start_sound_session(
        user_id=user["id"],
        track_id=track_id,
        is_dynamic=is_dynamic,
        dynamic_params=dynamic_params,
    )
    return {"session_id": session_id}


@router.post("/session/end", response_model=SoundSessionResponse)
async def end_sound_session(
    data: SoundSessionCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """End a sound healing session and record results."""
    session = await supabase.end_sound_session(
        user_id=user["id"],
        data=data.model_dump(),
    )
    logger.info(
        "Ended sound session",
        user_id=user["id"],
        duration=data.duration_listened_seconds,
        rating=data.effectiveness_rating,
    )
    return session


@router.get("/stream/{track_id}")
async def stream_sound_track(
    track_id: str,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
    storage: StorageService = Depends(get_storage_service),
):
    """Stream a sound healing track."""
    track = await supabase.get_sound_track_by_id(track_id)
    if not track:
        raise HTTPException(
            status_code=404,
            detail="Track not found",
        )

    audio_stream = await storage.get_audio_stream(track["audio_url"])

    return StreamingResponse(
        audio_stream,
        media_type="audio/mpeg",
        headers={
            "Content-Disposition": f"inline; filename=sound_{track_id}.mp3",
        },
    )


@router.get("/sessions", response_model=list[SoundSessionResponse])
async def get_sound_session_history(
    limit: int = Query(20, le=100),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get sound healing session history."""
    sessions = await supabase.get_sound_sessions(
        user_id=user["id"],
        limit=limit,
    )
    return sessions


@router.get("/track/{track_id}", response_model=SoundHealingTrack)
async def get_track_details(
    track_id: str,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get details for a specific sound healing track."""
    track = await supabase.get_sound_track_by_id(track_id)
    if not track:
        raise HTTPException(
            status_code=404,
            detail="Track not found",
        )
    return track
