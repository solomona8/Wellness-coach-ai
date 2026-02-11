"""iOS sync models for offline-first architecture."""

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class SyncEntry(BaseModel):
    """A single entry to sync."""

    entry_type: str = Field(
        ...,
        pattern="^(health_metric|sleep|exercise|diet|substance|mood|negativity|gratitude|meditation)$",
    )
    local_id: str
    data: dict[str, Any]
    action: str = Field(..., pattern="^(create|update|delete)$")
    created_at: datetime
    modified_at: datetime


class SyncPushRequest(BaseModel):
    """Request to push local changes to server."""

    device_id: str
    entries: list[SyncEntry]
    last_sync_at: Optional[datetime] = None


class SyncPushResponse(BaseModel):
    """Response after pushing changes."""

    synced_count: int
    failed_entries: list[dict]
    server_timestamp: datetime


class SyncPullRequest(BaseModel):
    """Request to pull changes from server."""

    device_id: str
    last_sync_at: Optional[datetime] = None
    entry_types: Optional[list[str]] = None


class SyncPullEntry(BaseModel):
    """An entry pulled from server."""

    entry_type: str
    server_id: str
    data: dict[str, Any]
    action: str
    modified_at: datetime


class SyncPullResponse(BaseModel):
    """Response with changes from server."""

    entries: list[SyncPullEntry]
    analyses: list[dict]
    podcasts: list[dict]
    server_timestamp: datetime
    has_more: bool


class SyncStatus(BaseModel):
    """Current sync status for a device."""

    device_id: str
    last_sync_at: Optional[datetime]
    pending_changes: int
    sync_errors: list[dict]
    is_syncing: bool


class SyncConflict(BaseModel):
    """A sync conflict to resolve."""

    entry_type: str
    local_id: str
    server_id: str
    local_data: dict[str, Any]
    server_data: dict[str, Any]
    local_modified_at: datetime
    server_modified_at: datetime


class SyncConflictResolution(BaseModel):
    """Resolution for a sync conflict."""

    conflict_id: str
    resolution: str = Field(..., pattern="^(keep_local|keep_server|merge)$")
    merged_data: Optional[dict[str, Any]] = None
