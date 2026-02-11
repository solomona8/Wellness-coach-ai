"""Audio-related models for podcasts and sound healing."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class PodcastResponse(BaseModel):
    """Response model for a podcast."""

    id: str
    user_id: str
    podcast_date: str
    title: Optional[str]
    script: str
    tldr: Optional[str] = None
    audio_url: Optional[str] = None
    duration_seconds: int
    voice_id: str
    listened: bool
    listened_at: Optional[datetime] = None
    generated_at: datetime


class PodcastListResponse(BaseModel):
    """Response model for podcast list."""

    podcasts: list[PodcastResponse]
    total: int
    page: int
    per_page: int


class SoundCategory(str, Enum):
    """Categories of sound healing tracks."""

    BINAURAL_BEATS = "binaural_beats"
    SOLFEGGIO = "solfeggio"
    NATURE = "nature"
    TIBETAN_BOWLS = "tibetan_bowls"
    WHITE_NOISE = "white_noise"
    CUSTOM = "custom"


class TargetState(str, Enum):
    """Target mental/physical states for sound healing."""

    RELAXATION = "relaxation"
    FOCUS = "focus"
    SLEEP = "sleep"
    MEDITATION = "meditation"
    ENERGY = "energy"
    STRESS_RELIEF = "stress_relief"
    HEALING = "healing"


class SoundHealingTrack(BaseModel):
    """Sound healing track from the library."""

    id: str
    title: str
    description: Optional[str]
    category: SoundCategory
    frequency_hz: Optional[float]
    secondary_frequency_hz: Optional[float]
    target_state: TargetState
    duration_seconds: int
    audio_url: str
    thumbnail_url: Optional[str]
    is_dynamic: bool
    popularity_score: float


class SoundRecommendation(BaseModel):
    """A personalized sound healing recommendation."""

    track: Optional[SoundHealingTrack] = None
    type: str = Field(default="library", pattern="^(library|dynamic)$")
    reason: str
    priority: int = Field(..., ge=1, le=10)
    based_on_metrics: Optional[dict] = None
    dynamic_params: Optional[dict] = None


class DynamicSoundRequest(BaseModel):
    """Request to generate dynamic sound healing."""

    target_state: TargetState
    duration_seconds: int = Field(600, ge=60, le=3600)
    base_frequency: Optional[float] = Field(None, ge=100, le=500)
    current_hrv: Optional[float] = None
    current_stress_level: Optional[int] = Field(None, ge=1, le=10)


class DynamicSoundResponse(BaseModel):
    """Response for dynamically generated sound."""

    audio_url: str
    duration_seconds: int
    frequencies: dict
    target_state: TargetState
    generation_params: dict


class SoundSessionCreate(BaseModel):
    """Create a sound healing session record."""

    track_id: Optional[str] = None
    is_dynamic: bool = False
    dynamic_params: Optional[dict] = None
    duration_listened_seconds: int
    pre_session_hrv: Optional[float] = None
    post_session_hrv: Optional[float] = None
    effectiveness_rating: Optional[int] = Field(None, ge=1, le=5)
    notes: Optional[str] = None
    started_at: datetime
    ended_at: Optional[datetime] = None


class SoundSessionResponse(BaseModel):
    """Response model for sound session."""

    id: str
    user_id: str
    track_id: Optional[str]
    is_dynamic: bool
    dynamic_params: Optional[dict]
    duration_listened_seconds: int
    pre_session_hrv: Optional[float]
    post_session_hrv: Optional[float]
    effectiveness_rating: Optional[int]
    notes: Optional[str]
    started_at: datetime
    ended_at: Optional[datetime]
    created_at: datetime
