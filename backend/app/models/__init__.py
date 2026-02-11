"""Pydantic models for API request/response validation."""

from app.models.health import (
    MetricType,
    HealthMetricCreate,
    HealthMetricResponse,
    HealthMetricBatchCreate,
    SleepSessionCreate,
    SleepSessionResponse,
    ExerciseType,
    ExerciseSessionCreate,
    ExerciseSessionResponse,
)
from app.models.tracking import (
    MealType,
    DietEntryCreate,
    DietEntryResponse,
    SubstanceType,
    SubstanceEntryCreate,
    SubstanceEntryResponse,
    MoodEntryCreate,
    MoodEntryResponse,
    NegativityType,
    NegativityEntryCreate,
    NegativityEntryResponse,
    GratitudeEntryCreate,
    GratitudeEntryResponse,
    MeditationType,
    MeditationSessionCreate,
    MeditationSessionResponse,
)
from app.models.analysis import (
    DailyAnalysisResponse,
    AnalysisRequest,
    WellnessScores,
    PatternDetection,
    CorrelationInsight,
    ActionItem,
)
from app.models.audio import (
    PodcastResponse,
    PodcastListResponse,
    SoundHealingTrack,
    SoundRecommendation,
    DynamicSoundRequest,
    DynamicSoundResponse,
    TargetState,
)
from app.models.user import (
    UserProfile,
    UserProfileUpdate,
    UserPreferences,
)
from app.models.sync import (
    SyncPushRequest,
    SyncPullResponse,
    SyncStatus,
)

__all__ = [
    # Health
    "MetricType",
    "HealthMetricCreate",
    "HealthMetricResponse",
    "HealthMetricBatchCreate",
    "SleepSessionCreate",
    "SleepSessionResponse",
    "ExerciseType",
    "ExerciseSessionCreate",
    "ExerciseSessionResponse",
    # Tracking
    "MealType",
    "DietEntryCreate",
    "DietEntryResponse",
    "SubstanceType",
    "SubstanceEntryCreate",
    "SubstanceEntryResponse",
    "MoodEntryCreate",
    "MoodEntryResponse",
    "NegativityType",
    "NegativityEntryCreate",
    "NegativityEntryResponse",
    "GratitudeEntryCreate",
    "GratitudeEntryResponse",
    "MeditationType",
    "MeditationSessionCreate",
    "MeditationSessionResponse",
    # Analysis
    "DailyAnalysisResponse",
    "AnalysisRequest",
    "WellnessScores",
    "PatternDetection",
    "CorrelationInsight",
    "ActionItem",
    # Audio
    "PodcastResponse",
    "PodcastListResponse",
    "SoundHealingTrack",
    "SoundRecommendation",
    "DynamicSoundRequest",
    "DynamicSoundResponse",
    "TargetState",
    # User
    "UserProfile",
    "UserProfileUpdate",
    "UserPreferences",
    # Sync
    "SyncPushRequest",
    "SyncPullResponse",
    "SyncStatus",
]
