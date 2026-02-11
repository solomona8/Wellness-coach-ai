"""User profile and settings endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
import structlog

from app.models.user import (
    UserProfile,
    UserProfileUpdate,
    UserPreferences,
    UserDataExport,
)
from app.core.auth import get_current_user
from app.services.supabase import SupabaseService, get_supabase_service

router = APIRouter()
logger = structlog.get_logger()


@router.get("/profile", response_model=UserProfile)
async def get_profile(
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get the current user's profile."""
    profile = await supabase.get_user_profile(user["id"])
    if not profile:
        raise HTTPException(
            status_code=404,
            detail="Profile not found",
        )
    return profile


@router.put("/profile", response_model=UserProfile)
async def update_profile(
    data: UserProfileUpdate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Update the current user's profile."""
    # Filter out None values
    update_data = {k: v for k, v in data.model_dump().items() if v is not None}

    if not update_data:
        raise HTTPException(
            status_code=400,
            detail="No fields to update",
        )

    profile = await supabase.update_user_profile(
        user_id=user["id"],
        data=update_data,
    )
    logger.info("Updated user profile", user_id=user["id"])
    return profile


@router.put("/preferences", response_model=UserProfile)
async def update_preferences(
    preferences: UserPreferences,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Update user preferences."""
    profile = await supabase.update_user_profile(
        user_id=user["id"],
        data=preferences.model_dump(),
    )
    logger.info("Updated user preferences", user_id=user["id"])
    return profile


@router.delete("/account")
async def delete_account(
    confirm: bool = False,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Delete user account and all associated data (GDPR compliance)."""
    if not confirm:
        raise HTTPException(
            status_code=400,
            detail="Please confirm account deletion by setting confirm=true",
        )

    try:
        await supabase.delete_user_account(user["id"])
        logger.warning("Deleted user account", user_id=user["id"])
        return {"status": "account deleted"}
    except Exception as e:
        logger.error("Failed to delete account", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to delete account",
        )


@router.get("/export")
async def export_user_data(
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Export all user data (GDPR compliance)."""
    try:
        data = await supabase.export_user_data(user["id"])
        logger.info("Exported user data", user_id=user["id"])

        return JSONResponse(
            content=data,
            headers={
                "Content-Disposition": f"attachment; filename=wellness_data_export.json"
            },
        )
    except Exception as e:
        logger.error("Failed to export data", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to export data",
        )


@router.post("/onboarding/complete")
async def complete_onboarding(
    health_goals: list[str] = None,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Mark onboarding as complete."""
    update_data = {"onboarding_completed": True}
    if health_goals:
        update_data["health_goals"] = health_goals

    profile = await supabase.update_user_profile(
        user_id=user["id"],
        data=update_data,
    )
    logger.info("Completed onboarding", user_id=user["id"])
    return {"status": "onboarding completed", "profile": profile}


@router.get("/voices", response_model=list[dict])
async def get_available_voices(
    user: dict = Depends(get_current_user),
):
    """Get available voice options for podcast generation."""
    # These are ElevenLabs voices that can be used
    voices = [
        {
            "id": "default",
            "name": "Rachel",
            "description": "Warm and friendly female voice",
            "preview_url": None,
        },
        {
            "id": "21m00Tcm4TlvDq8ikWAM",
            "name": "Rachel",
            "description": "Warm and friendly female voice",
            "preview_url": None,
        },
        {
            "id": "AZnzlk1XvdvUeBnXmlld",
            "name": "Domi",
            "description": "Strong and clear female voice",
            "preview_url": None,
        },
        {
            "id": "EXAVITQu4vr4xnSDxMaL",
            "name": "Bella",
            "description": "Soft and soothing female voice",
            "preview_url": None,
        },
        {
            "id": "ErXwobaYiN019PkySvjV",
            "name": "Antoni",
            "description": "Well-rounded male voice",
            "preview_url": None,
        },
        {
            "id": "VR6AewLTigWG4xSOukaG",
            "name": "Arnold",
            "description": "Crisp and professional male voice",
            "preview_url": None,
        },
    ]
    return voices
