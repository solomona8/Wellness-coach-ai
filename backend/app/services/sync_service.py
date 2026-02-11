"""Sync service for iOS offline-first architecture."""

from datetime import datetime
from typing import Optional

from fastapi import Depends
import structlog

from app.config import Settings, get_settings
from app.models.sync import (
    SyncEntry,
    SyncPushResponse,
    SyncPullResponse,
    SyncPullEntry,
    SyncStatus,
    SyncConflict,
    SyncConflictResolution,
)
from app.services.supabase import SupabaseService, get_supabase_service

logger = structlog.get_logger()


class SyncService:
    """Service for handling iOS offline sync."""

    # Mapping of entry types to table names and date fields
    ENTRY_CONFIG = {
        "health_metric": ("health_metrics", "recorded_at"),
        "sleep": ("sleep_sessions", "start_time"),
        "exercise": ("exercise_sessions", "started_at"),
        "diet": ("diet_entries", "logged_at"),
        "substance": ("substance_entries", "logged_at"),
        "mood": ("mood_entries", "logged_at"),
        "negativity": ("negativity_entries", "logged_at"),
        "gratitude": ("gratitude_entries", "logged_at"),
        "meditation": ("meditation_sessions", "started_at"),
    }

    def __init__(self, settings: Settings, supabase: SupabaseService):
        self.supabase = supabase

    async def push_changes(
        self,
        user_id: str,
        device_id: str,
        entries: list[SyncEntry],
        last_sync_at: Optional[datetime],
    ) -> SyncPushResponse:
        """Push local changes to server."""
        synced_count = 0
        failed_entries = []

        for entry in entries:
            try:
                await self._process_entry(user_id, entry)
                synced_count += 1
            except Exception as e:
                logger.error(
                    "Failed to sync entry",
                    entry_type=entry.entry_type,
                    local_id=entry.local_id,
                    error=str(e),
                )
                failed_entries.append({
                    "local_id": entry.local_id,
                    "entry_type": entry.entry_type,
                    "error": str(e),
                })

        # Update sync status
        await self._update_sync_status(
            user_id=user_id,
            device_id=device_id,
            last_sync_at=datetime.utcnow(),
            pending_changes=len(failed_entries),
            sync_errors=failed_entries,
        )

        return SyncPushResponse(
            synced_count=synced_count,
            failed_entries=failed_entries,
            server_timestamp=datetime.utcnow(),
        )

    async def _process_entry(self, user_id: str, entry: SyncEntry) -> None:
        """Process a single sync entry."""
        config = self.ENTRY_CONFIG.get(entry.entry_type)
        if not config:
            raise ValueError(f"Unknown entry type: {entry.entry_type}")

        table_name, date_field = config
        data = entry.data.copy()
        data["user_id"] = user_id

        if entry.action == "create":
            result = self.supabase.client.table(table_name).insert(data).execute()
        elif entry.action == "update":
            # Assume data contains server_id for updates
            server_id = data.pop("id", None)
            if server_id:
                result = (
                    self.supabase.client.table(table_name)
                    .update(data)
                    .eq("id", server_id)
                    .eq("user_id", user_id)
                    .execute()
                )
        elif entry.action == "delete":
            server_id = data.get("id")
            if server_id:
                result = (
                    self.supabase.client.table(table_name)
                    .delete()
                    .eq("id", server_id)
                    .eq("user_id", user_id)
                    .execute()
                )

    async def pull_changes(
        self,
        user_id: str,
        device_id: str,
        last_sync_at: Optional[str],
    ) -> SyncPullResponse:
        """Pull changes from server since last sync."""
        entries = []
        since = (
            datetime.fromisoformat(last_sync_at)
            if last_sync_at
            else datetime.min
        )

        # Pull changes from each table
        for entry_type, (table_name, date_field) in self.ENTRY_CONFIG.items():
            table_entries = await self._pull_table_changes(
                user_id=user_id,
                table_name=table_name,
                entry_type=entry_type,
                since=since,
            )
            entries.extend(table_entries)

        # Pull analyses and podcasts
        analyses = await self.supabase.get_recent_analyses(user_id, limit=7)
        podcasts = await self.supabase.get_podcasts(user_id, limit=7)

        return SyncPullResponse(
            entries=entries,
            analyses=analyses,
            podcasts=podcasts,
            server_timestamp=datetime.utcnow(),
            has_more=False,  # Implement pagination if needed
        )

    async def _pull_table_changes(
        self,
        user_id: str,
        table_name: str,
        entry_type: str,
        since: datetime,
    ) -> list[SyncPullEntry]:
        """Pull changes from a specific table."""
        result = (
            self.supabase.client.table(table_name)
            .select("*")
            .eq("user_id", user_id)
            .gte("created_at", since.isoformat())
            .execute()
        )

        entries = []
        for row in result.data:
            entries.append(SyncPullEntry(
                entry_type=entry_type,
                server_id=row["id"],
                data=row,
                action="upsert",
                modified_at=row.get("created_at", datetime.utcnow().isoformat()),
            ))

        return entries

    async def get_sync_status(
        self,
        user_id: str,
        device_id: str,
    ) -> SyncStatus:
        """Get current sync status for a device."""
        result = (
            self.supabase.client.table("sync_status")
            .select("*")
            .eq("user_id", user_id)
            .eq("device_id", device_id)
            .single()
            .execute()
        )

        if result.data:
            return SyncStatus(
                device_id=device_id,
                last_sync_at=result.data.get("last_sync_at"),
                pending_changes=result.data.get("pending_changes", 0),
                sync_errors=result.data.get("sync_errors", []),
                is_syncing=False,
            )

        return SyncStatus(
            device_id=device_id,
            last_sync_at=None,
            pending_changes=0,
            sync_errors=[],
            is_syncing=False,
        )

    async def _update_sync_status(
        self,
        user_id: str,
        device_id: str,
        last_sync_at: datetime,
        pending_changes: int,
        sync_errors: list,
    ) -> None:
        """Update sync status for a device."""
        data = {
            "user_id": user_id,
            "device_id": device_id,
            "last_sync_at": last_sync_at.isoformat(),
            "pending_changes": pending_changes,
            "sync_errors": sync_errors,
        }

        self.supabase.client.table("sync_status").upsert(
            data,
            on_conflict="user_id,device_id",
        ).execute()

    async def get_conflicts(
        self,
        user_id: str,
        device_id: str,
    ) -> list[SyncConflict]:
        """Get pending sync conflicts."""
        # In a full implementation, this would track conflicts
        # For now, we use a last-write-wins strategy
        return []

    async def resolve_conflict(
        self,
        user_id: str,
        resolution: SyncConflictResolution,
    ) -> None:
        """Resolve a sync conflict."""
        # Implementation would handle conflict resolution
        pass

    async def reset_sync(
        self,
        user_id: str,
        device_id: str,
    ) -> None:
        """Reset sync state for a device."""
        self.supabase.client.table("sync_status").delete().eq(
            "user_id", user_id
        ).eq("device_id", device_id).execute()

        logger.warning(
            "Reset sync state",
            user_id=user_id,
            device_id=device_id,
        )


def get_sync_service(
    settings: Settings = Depends(get_settings),
    supabase: SupabaseService = Depends(get_supabase_service),
) -> SyncService:
    """Get sync service instance."""
    return SyncService(settings, supabase)
