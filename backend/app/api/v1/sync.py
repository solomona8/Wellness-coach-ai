"""iOS sync endpoints for offline-first architecture."""

from fastapi import APIRouter, Depends, HTTPException
import structlog

from app.models.sync import (
    SyncPushRequest,
    SyncPushResponse,
    SyncPullResponse,
    SyncStatus,
    SyncConflict,
    SyncConflictResolution,
)
from app.core.auth import get_current_user
from app.services.supabase import SupabaseService, get_supabase_service
from app.services.sync_service import SyncService, get_sync_service

router = APIRouter()
logger = structlog.get_logger()


@router.post("/push", response_model=SyncPushResponse)
async def push_changes(
    data: SyncPushRequest,
    user: dict = Depends(get_current_user),
    sync_service: SyncService = Depends(get_sync_service),
):
    """Push local changes to server."""
    try:
        result = await sync_service.push_changes(
            user_id=user["id"],
            device_id=data.device_id,
            entries=data.entries,
            last_sync_at=data.last_sync_at,
        )
        logger.info(
            "Pushed sync changes",
            user_id=user["id"],
            device_id=data.device_id,
            count=len(data.entries),
            synced=result.synced_count,
        )
        return result
    except Exception as e:
        logger.error("Failed to push sync changes", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to sync changes",
        )


@router.get("/pull", response_model=SyncPullResponse)
async def pull_changes(
    device_id: str,
    last_sync_at: str = None,
    user: dict = Depends(get_current_user),
    sync_service: SyncService = Depends(get_sync_service),
):
    """Pull changes from server."""
    try:
        result = await sync_service.pull_changes(
            user_id=user["id"],
            device_id=device_id,
            last_sync_at=last_sync_at,
        )
        logger.info(
            "Pulled sync changes",
            user_id=user["id"],
            device_id=device_id,
            entries_count=len(result.entries),
        )
        return result
    except Exception as e:
        logger.error("Failed to pull sync changes", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to pull changes",
        )


@router.get("/status", response_model=SyncStatus)
async def get_sync_status(
    device_id: str,
    user: dict = Depends(get_current_user),
    sync_service: SyncService = Depends(get_sync_service),
):
    """Get current sync status for a device."""
    status = await sync_service.get_sync_status(
        user_id=user["id"],
        device_id=device_id,
    )
    return status


@router.get("/conflicts", response_model=list[SyncConflict])
async def get_conflicts(
    device_id: str,
    user: dict = Depends(get_current_user),
    sync_service: SyncService = Depends(get_sync_service),
):
    """Get pending sync conflicts."""
    conflicts = await sync_service.get_conflicts(
        user_id=user["id"],
        device_id=device_id,
    )
    return conflicts


@router.post("/resolve", response_model=dict)
async def resolve_conflict(
    resolution: SyncConflictResolution,
    user: dict = Depends(get_current_user),
    sync_service: SyncService = Depends(get_sync_service),
):
    """Resolve a sync conflict."""
    try:
        await sync_service.resolve_conflict(
            user_id=user["id"],
            resolution=resolution,
        )
        logger.info(
            "Resolved sync conflict",
            user_id=user["id"],
            conflict_id=resolution.conflict_id,
            resolution=resolution.resolution,
        )
        return {"status": "resolved"}
    except Exception as e:
        logger.error("Failed to resolve conflict", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to resolve conflict",
        )


@router.post("/reset", response_model=dict)
async def reset_sync(
    device_id: str,
    user: dict = Depends(get_current_user),
    sync_service: SyncService = Depends(get_sync_service),
):
    """Reset sync state for a device (use with caution)."""
    await sync_service.reset_sync(
        user_id=user["id"],
        device_id=device_id,
    )
    logger.warning(
        "Reset sync state",
        user_id=user["id"],
        device_id=device_id,
    )
    return {"status": "sync reset"}
