"""Manual tracking endpoints."""

from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
import structlog

from app.models.tracking import (
    DietEntryCreate,
    DietEntryResponse,
    SubstanceEntryCreate,
    SubstanceEntryResponse,
    MoodEntryCreate,
    MoodEntryResponse,
    NegativityEntryCreate,
    NegativityEntryResponse,
    GratitudeEntryCreate,
    GratitudeEntryResponse,
    MeditationSessionCreate,
    MeditationSessionResponse,
    MealType,
    SubstanceType,
    NegativityType,
)
from app.core.auth import get_current_user
from app.services.supabase import SupabaseService, get_supabase_service
from app.services.storage import StorageService, get_storage_service

router = APIRouter()
logger = structlog.get_logger()


# Diet Tracking
@router.post("/diet", response_model=DietEntryResponse)
async def log_diet_entry(
    data: DietEntryCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Log a diet/meal entry."""
    entry = await supabase.insert_diet_entry(user_id=user["id"], data=data.model_dump())
    logger.info("Logged diet entry", user_id=user["id"], meal_type=data.meal_type)
    return entry


@router.post("/diet/photo", response_model=dict)
async def upload_meal_photo(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
    storage: StorageService = Depends(get_storage_service),
):
    """Upload a meal photo and return the URL."""
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    url = await storage.upload_meal_photo(user_id=user["id"], file=file)
    return {"photo_url": url}


@router.get("/diet", response_model=list[DietEntryResponse])
async def get_diet_history(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    meal_type: Optional[MealType] = None,
    limit: int = Query(50, le=200),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get diet entry history."""
    entries = await supabase.get_diet_entries(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        meal_type=meal_type,
        limit=limit,
    )
    return entries


# Substance Tracking
@router.post("/substance", response_model=SubstanceEntryResponse)
async def log_substance_entry(
    data: SubstanceEntryCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Log a substance (alcohol, caffeine, etc.) entry."""
    entry = await supabase.insert_substance_entry(
        user_id=user["id"], data=data.model_dump()
    )
    logger.info(
        "Logged substance entry",
        user_id=user["id"],
        substance_type=data.substance_type,
    )
    return entry


@router.get("/substance", response_model=list[SubstanceEntryResponse])
async def get_substance_history(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    substance_type: Optional[SubstanceType] = None,
    limit: int = Query(50, le=200),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get substance entry history."""
    entries = await supabase.get_substance_entries(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        substance_type=substance_type,
        limit=limit,
    )
    return entries


# Mood Tracking
@router.post("/mood", response_model=MoodEntryResponse)
async def log_mood_entry(
    data: MoodEntryCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Log a mood/stress entry."""
    entry = await supabase.insert_mood_entry(user_id=user["id"], data=data.model_dump())
    logger.info("Logged mood entry", user_id=user["id"], mood_score=data.mood_score)
    return entry


@router.get("/mood", response_model=list[MoodEntryResponse])
async def get_mood_history(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    limit: int = Query(50, le=200),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get mood entry history."""
    entries = await supabase.get_mood_entries(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )
    return entries


# Negativity Tracking
@router.post("/negativity", response_model=NegativityEntryResponse)
async def log_negativity_entry(
    data: NegativityEntryCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Log a negativity exposure entry."""
    entry = await supabase.insert_negativity_entry(
        user_id=user["id"], data=data.model_dump()
    )
    logger.info(
        "Logged negativity entry",
        user_id=user["id"],
        exposure_type=data.exposure_type,
    )
    return entry


@router.get("/negativity", response_model=list[NegativityEntryResponse])
async def get_negativity_history(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    exposure_type: Optional[NegativityType] = None,
    limit: int = Query(50, le=200),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get negativity entry history."""
    entries = await supabase.get_negativity_entries(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        exposure_type=exposure_type,
        limit=limit,
    )
    return entries


# Gratitude Tracking
@router.post("/gratitude", response_model=GratitudeEntryResponse)
async def log_gratitude_entry(
    data: GratitudeEntryCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Log a gratitude entry."""
    entry = await supabase.insert_gratitude_entry(
        user_id=user["id"], data=data.model_dump()
    )
    logger.info(
        "Logged gratitude entry",
        user_id=user["id"],
        items_count=len(data.gratitude_items),
    )
    return entry


@router.get("/gratitude", response_model=list[GratitudeEntryResponse])
async def get_gratitude_history(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    limit: int = Query(50, le=200),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get gratitude entry history."""
    entries = await supabase.get_gratitude_entries(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )
    return entries


# Meditation Tracking
@router.post("/meditation", response_model=MeditationSessionResponse)
async def log_meditation_session(
    data: MeditationSessionCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Log a meditation session."""
    entry = await supabase.insert_meditation_session(
        user_id=user["id"], data=data.model_dump()
    )
    logger.info(
        "Logged meditation session",
        user_id=user["id"],
        duration=data.duration_minutes,
    )
    return entry


@router.get("/meditation", response_model=list[MeditationSessionResponse])
async def get_meditation_history(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    limit: int = Query(50, le=200),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get meditation session history."""
    sessions = await supabase.get_meditation_sessions(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )
    return sessions
