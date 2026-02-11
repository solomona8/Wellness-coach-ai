"""Supabase client and database operations."""

from datetime import date, datetime, timedelta
from typing import Any, Optional

from fastapi import Depends
from supabase import create_client, Client
import structlog

from app.config import Settings, get_settings

logger = structlog.get_logger()


class SupabaseService:
    """Service for Supabase database operations."""

    def __init__(self, settings: Settings):
        self.client: Client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key,
        )

    # Health Metrics
    async def batch_insert_health_metrics(
        self,
        user_id: str,
        metrics: list[dict],
        device_id: str,
    ) -> list[dict]:
        """Batch insert health metrics."""
        records = [
            {
                **metric,
                "user_id": user_id,
                "recorded_at": metric["recorded_at"].isoformat()
                if isinstance(metric["recorded_at"], datetime)
                else metric["recorded_at"],
            }
            for metric in metrics
        ]

        result = (
            self.client.table("health_metrics")
            .upsert(records, on_conflict="user_id,metric_type,recorded_at,source")
            .execute()
        )
        return result.data

    async def get_health_metrics(
        self,
        user_id: str,
        metric_type: Optional[str] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[dict]:
        """Get health metrics with filters."""
        query = (
            self.client.table("health_metrics")
            .select("*")
            .eq("user_id", user_id)
            .order("recorded_at", desc=True)
            .limit(limit)
            .offset(offset)
        )

        if metric_type:
            query = query.eq("metric_type", metric_type)
        if start_date:
            query = query.gte("recorded_at", start_date.isoformat())
        if end_date:
            query = query.lte("recorded_at", end_date.isoformat())

        result = query.execute()
        return result.data

    async def get_health_summary(self, user_id: str, date: date) -> dict:
        """Get health metrics summary for a date."""
        start = datetime.combine(date, datetime.min.time())
        end = datetime.combine(date, datetime.max.time())

        metrics = await self.get_health_metrics(
            user_id=user_id,
            start_date=date,
            end_date=date,
            limit=1000,
        )

        # Aggregate metrics
        summary = {}
        for metric in metrics:
            metric_type = metric["metric_type"]
            if metric_type not in summary:
                summary[metric_type] = {"values": [], "count": 0}
            summary[metric_type]["values"].append(metric["value"])
            summary[metric_type]["count"] += 1

        # Calculate averages
        for metric_type, data in summary.items():
            if data["values"]:
                data["avg"] = sum(data["values"]) / len(data["values"])
                data["min"] = min(data["values"])
                data["max"] = max(data["values"])
            del data["values"]

        return summary

    # Sleep Sessions
    async def insert_sleep_session(self, user_id: str, data: dict) -> dict:
        """Insert a sleep session."""
        record = {
            **data,
            "user_id": user_id,
            "start_time": data["start_time"].isoformat()
            if isinstance(data["start_time"], datetime)
            else data["start_time"],
            "end_time": data["end_time"].isoformat()
            if isinstance(data["end_time"], datetime)
            else data["end_time"],
        }

        result = self.client.table("sleep_sessions").insert(record).execute()
        return result.data[0] if result.data else None

    async def get_sleep_sessions(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 30,
    ) -> list[dict]:
        """Get sleep sessions."""
        query = (
            self.client.table("sleep_sessions")
            .select("*")
            .eq("user_id", user_id)
            .order("start_time", desc=True)
            .limit(limit)
        )

        if start_date:
            query = query.gte("start_time", start_date.isoformat())
        if end_date:
            query = query.lte("start_time", end_date.isoformat())

        result = query.execute()
        return result.data

    # Exercise Sessions
    async def insert_exercise_session(self, user_id: str, data: dict) -> dict:
        """Insert an exercise session."""
        record = {
            **data,
            "user_id": user_id,
            "started_at": data["started_at"].isoformat()
            if isinstance(data["started_at"], datetime)
            else data["started_at"],
        }
        if data.get("ended_at"):
            record["ended_at"] = (
                data["ended_at"].isoformat()
                if isinstance(data["ended_at"], datetime)
                else data["ended_at"]
            )

        result = self.client.table("exercise_sessions").insert(record).execute()
        return result.data[0] if result.data else None

    async def get_exercise_sessions(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 30,
    ) -> list[dict]:
        """Get exercise sessions."""
        query = (
            self.client.table("exercise_sessions")
            .select("*")
            .eq("user_id", user_id)
            .order("started_at", desc=True)
            .limit(limit)
        )

        if start_date:
            query = query.gte("started_at", start_date.isoformat())
        if end_date:
            query = query.lte("started_at", end_date.isoformat())

        result = query.execute()
        return result.data

    # Manual Tracking - Generic insert methods
    async def insert_diet_entry(self, user_id: str, data: dict) -> dict:
        """Insert a diet entry."""
        return await self._insert_entry("diet_entries", user_id, data, "logged_at")

    async def get_diet_entries(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        meal_type: Optional[str] = None,
        limit: int = 50,
    ) -> list[dict]:
        """Get diet entries."""
        query = (
            self.client.table("diet_entries")
            .select("*")
            .eq("user_id", user_id)
            .order("logged_at", desc=True)
            .limit(limit)
        )

        if start_date:
            query = query.gte("logged_at", start_date.isoformat())
        if end_date:
            query = query.lte("logged_at", end_date.isoformat())
        if meal_type:
            query = query.eq("meal_type", meal_type)

        result = query.execute()
        return result.data

    async def insert_substance_entry(self, user_id: str, data: dict) -> dict:
        """Insert a substance entry."""
        return await self._insert_entry("substance_entries", user_id, data, "logged_at")

    async def get_substance_entries(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        substance_type: Optional[str] = None,
        limit: int = 50,
    ) -> list[dict]:
        """Get substance entries."""
        return await self._get_entries(
            "substance_entries",
            user_id,
            "logged_at",
            start_date,
            end_date,
            limit,
            extra_filters={"substance_type": substance_type} if substance_type else None,
        )

    async def insert_mood_entry(self, user_id: str, data: dict) -> dict:
        """Insert a mood entry."""
        return await self._insert_entry("mood_entries", user_id, data, "logged_at")

    async def get_mood_entries(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 50,
    ) -> list[dict]:
        """Get mood entries."""
        return await self._get_entries(
            "mood_entries", user_id, "logged_at", start_date, end_date, limit
        )

    async def insert_negativity_entry(self, user_id: str, data: dict) -> dict:
        """Insert a negativity entry."""
        return await self._insert_entry("negativity_entries", user_id, data, "logged_at")

    async def get_negativity_entries(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        exposure_type: Optional[str] = None,
        limit: int = 50,
    ) -> list[dict]:
        """Get negativity entries."""
        return await self._get_entries(
            "negativity_entries",
            user_id,
            "logged_at",
            start_date,
            end_date,
            limit,
            extra_filters={"exposure_type": exposure_type} if exposure_type else None,
        )

    async def insert_gratitude_entry(self, user_id: str, data: dict) -> dict:
        """Insert a gratitude entry."""
        return await self._insert_entry("gratitude_entries", user_id, data, "logged_at")

    async def get_gratitude_entries(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 50,
    ) -> list[dict]:
        """Get gratitude entries."""
        return await self._get_entries(
            "gratitude_entries", user_id, "logged_at", start_date, end_date, limit
        )

    async def insert_meditation_session(self, user_id: str, data: dict) -> dict:
        """Insert a meditation session."""
        return await self._insert_entry(
            "meditation_sessions", user_id, data, "started_at"
        )

    async def get_meditation_sessions(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        limit: int = 50,
    ) -> list[dict]:
        """Get meditation sessions."""
        return await self._get_entries(
            "meditation_sessions", user_id, "started_at", start_date, end_date, limit
        )

    # Analysis
    async def get_daily_analysis(
        self, user_id: str, analysis_date: date
    ) -> Optional[dict]:
        """Get daily analysis for a date."""
        try:
            result = (
                self.client.table("daily_analyses")
                .select("*")
                .eq("user_id", user_id)
                .eq("analysis_date", analysis_date.isoformat())
                .maybe_single()  # Use maybe_single to handle 0 rows without error
                .execute()
            )
            return result.data
        except Exception:
            return None

    async def upsert_daily_analysis(self, data: dict) -> dict:
        """Insert or update daily analysis."""
        result = (
            self.client.table("daily_analyses")
            .upsert(data, on_conflict="user_id,analysis_date")
            .execute()
        )
        return result.data[0] if result.data else None

    async def get_recent_analyses(self, user_id: str, limit: int = 7) -> list[dict]:
        """Get recent analyses."""
        result = (
            self.client.table("daily_analyses")
            .select("*")
            .eq("user_id", user_id)
            .order("analysis_date", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data

    # Podcasts
    async def get_podcast_by_date(self, user_id: str, podcast_date: date) -> Optional[dict]:
        """Get podcast by date."""
        try:
            result = (
                self.client.table("daily_podcasts")
                .select("*")
                .eq("user_id", user_id)
                .eq("podcast_date", podcast_date.isoformat())
                .maybe_single()
                .execute()
            )
            return result.data
        except Exception:
            return None

    async def get_podcast_by_id(self, user_id: str, podcast_id: str) -> Optional[dict]:
        """Get podcast by ID."""
        try:
            result = (
                self.client.table("daily_podcasts")
                .select("*")
                .eq("user_id", user_id)
                .eq("id", podcast_id)
                .maybe_single()
                .execute()
            )
            return result.data
        except Exception:
            return None

    async def get_podcasts(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> list[dict]:
        """Get podcasts with pagination."""
        try:
            result = (
                self.client.table("daily_podcasts")
                .select("*")
                .eq("user_id", user_id)
                .order("podcast_date", desc=True)
                .limit(limit)
                .offset(offset)
                .execute()
            )
            return result.data or []
        except Exception:
            return []

    async def count_podcasts(self, user_id: str) -> int:
        """Count total podcasts."""
        try:
            result = (
                self.client.table("daily_podcasts")
                .select("id", count="exact")
                .eq("user_id", user_id)
                .execute()
            )
            return result.count or 0
        except Exception:
            return 0

    async def insert_podcast(self, data: dict) -> dict:
        """Insert a podcast."""
        result = self.client.table("daily_podcasts").insert(data).execute()
        return result.data[0] if result.data else None

    async def mark_podcast_listened(self, user_id: str, podcast_id: str) -> bool:
        """Mark podcast as listened."""
        result = (
            self.client.table("daily_podcasts")
            .update({"listened": True, "listened_at": datetime.utcnow().isoformat()})
            .eq("user_id", user_id)
            .eq("id", podcast_id)
            .execute()
        )
        return len(result.data) > 0

    # Sound Healing
    async def get_sound_tracks(
        self,
        category: Optional[str] = None,
        target_state: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict]:
        """Get sound healing tracks."""
        query = (
            self.client.table("sound_healing_tracks")
            .select("*")
            .order("popularity_score", desc=True)
            .limit(limit)
            .offset(offset)
        )

        if category:
            query = query.eq("category", category)
        if target_state:
            query = query.eq("target_state", target_state)

        result = query.execute()
        return result.data

    async def get_sound_track_by_id(self, track_id: str) -> Optional[dict]:
        """Get sound track by ID."""
        result = (
            self.client.table("sound_healing_tracks")
            .select("*")
            .eq("id", track_id)
            .single()
            .execute()
        )
        return result.data

    async def start_sound_session(
        self,
        user_id: str,
        track_id: Optional[str],
        is_dynamic: bool,
        dynamic_params: Optional[dict],
    ) -> str:
        """Start a sound session."""
        record = {
            "user_id": user_id,
            "track_id": track_id,
            "is_dynamic": is_dynamic,
            "dynamic_params": dynamic_params or {},
            "started_at": datetime.utcnow().isoformat(),
        }
        result = self.client.table("sound_healing_sessions").insert(record).execute()
        return result.data[0]["id"] if result.data else None

    async def end_sound_session(self, user_id: str, data: dict) -> dict:
        """End a sound session."""
        return await self._insert_entry(
            "sound_healing_sessions", user_id, data, "started_at"
        )

    async def get_sound_sessions(self, user_id: str, limit: int = 20) -> list[dict]:
        """Get sound sessions."""
        result = (
            self.client.table("sound_healing_sessions")
            .select("*")
            .eq("user_id", user_id)
            .order("started_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data

    # User Profile
    async def get_user_profile(self, user_id: str) -> Optional[dict]:
        """Get user profile."""
        try:
            result = (
                self.client.table("user_profiles")
                .select("*")
                .eq("id", user_id)
                .maybe_single()  # Use maybe_single to handle 0 rows without error
                .execute()
            )
            return result.data if result.data else {}
        except Exception as e:
            # Return empty dict if profile doesn't exist
            return {}

    async def update_user_profile(self, user_id: str, data: dict) -> dict:
        """Update user profile."""
        data["updated_at"] = datetime.utcnow().isoformat()
        result = (
            self.client.table("user_profiles")
            .update(data)
            .eq("id", user_id)
            .execute()
        )
        return result.data[0] if result.data else None

    async def delete_user_account(self, user_id: str) -> None:
        """Delete user account and all data."""
        # Delete in order due to foreign keys
        tables = [
            "sound_healing_sessions",
            "sound_recommendations",
            "daily_podcasts",
            "daily_analyses",
            "meditation_sessions",
            "gratitude_entries",
            "negativity_entries",
            "mood_entries",
            "substance_entries",
            "diet_entries",
            "exercise_sessions",
            "sleep_sessions",
            "health_metrics",
            "sync_status",
            "user_profiles",
        ]

        for table in tables:
            self.client.table(table).delete().eq("user_id", user_id).execute()

    async def export_user_data(self, user_id: str) -> dict:
        """Export all user data."""
        tables = {
            "user_profile": "user_profiles",
            "health_metrics": "health_metrics",
            "sleep_sessions": "sleep_sessions",
            "exercise_sessions": "exercise_sessions",
            "diet_entries": "diet_entries",
            "substance_entries": "substance_entries",
            "mood_entries": "mood_entries",
            "negativity_entries": "negativity_entries",
            "gratitude_entries": "gratitude_entries",
            "meditation_sessions": "meditation_sessions",
            "daily_analyses": "daily_analyses",
            "daily_podcasts": "daily_podcasts",
            "sound_sessions": "sound_healing_sessions",
        }

        export = {"exported_at": datetime.utcnow().isoformat()}

        for key, table in tables.items():
            id_field = "id" if table == "user_profiles" else "user_id"
            result = (
                self.client.table(table).select("*").eq(id_field, user_id).execute()
            )
            export[key] = result.data if key != "user_profile" else (result.data[0] if result.data else None)

        return export

    # Helper methods
    async def _insert_entry(
        self, table: str, user_id: str, data: dict, date_field: str
    ) -> dict:
        """Generic insert for tracking entries."""
        record = {**data, "user_id": user_id}

        # Convert datetime to ISO string
        if date_field in record and isinstance(record[date_field], datetime):
            record[date_field] = record[date_field].isoformat()

        result = self.client.table(table).insert(record).execute()
        return result.data[0] if result.data else None

    async def _get_entries(
        self,
        table: str,
        user_id: str,
        date_field: str,
        start_date: Optional[date],
        end_date: Optional[date],
        limit: int,
        extra_filters: Optional[dict] = None,
    ) -> list[dict]:
        """Generic get for tracking entries."""
        query = (
            self.client.table(table)
            .select("*")
            .eq("user_id", user_id)
            .order(date_field, desc=True)
            .limit(limit)
        )

        if start_date:
            query = query.gte(date_field, start_date.isoformat())
        if end_date:
            query = query.lte(date_field, end_date.isoformat())
        if extra_filters:
            for key, value in extra_filters.items():
                if value is not None:
                    query = query.eq(key, value)

        result = query.execute()
        return result.data


# Dependency injection
def get_supabase_service(settings: Settings = Depends(get_settings)) -> SupabaseService:
    """Get Supabase service instance."""
    return SupabaseService(settings)
