"""User profile and preferences models."""

from datetime import datetime, time
from typing import Optional

from pydantic import BaseModel, Field


class NotificationSettings(BaseModel):
    """User notification preferences."""

    podcast_ready: bool = True
    daily_reminder: bool = True
    weekly_summary: bool = True
    achievement_alerts: bool = True
    sound_healing_suggestions: bool = True


class UserPreferences(BaseModel):
    """User preferences for the app."""

    preferred_podcast_time: time = Field(default=time(7, 0))
    voice_preference: str = "default"
    timezone: str = "UTC"
    notification_settings: NotificationSettings = Field(
        default_factory=NotificationSettings
    )
    health_goals: list[str] = Field(default_factory=list)
    dark_mode: bool = False
    metric_units: bool = False


class UserProfile(BaseModel):
    """User profile response."""

    id: str
    email: str
    display_name: Optional[str]
    avatar_url: Optional[str]
    timezone: str
    preferred_podcast_time: time
    voice_preference: str
    notification_settings: dict
    health_goals: list[str]
    onboarding_completed: bool
    created_at: datetime
    updated_at: datetime


class UserProfileUpdate(BaseModel):
    """Update user profile."""

    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    timezone: Optional[str] = None
    preferred_podcast_time: Optional[time] = None
    voice_preference: Optional[str] = None
    notification_settings: Optional[NotificationSettings] = None
    health_goals: Optional[list[str]] = None
    onboarding_completed: Optional[bool] = None


class UserDataExport(BaseModel):
    """GDPR data export response."""

    user_profile: dict
    health_metrics: list[dict]
    sleep_sessions: list[dict]
    exercise_sessions: list[dict]
    diet_entries: list[dict]
    substance_entries: list[dict]
    mood_entries: list[dict]
    negativity_entries: list[dict]
    gratitude_entries: list[dict]
    meditation_sessions: list[dict]
    daily_analyses: list[dict]
    daily_podcasts: list[dict]
    sound_sessions: list[dict]
    exported_at: datetime
