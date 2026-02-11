"""Manual tracking data models."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class MealType(str, Enum):
    """Types of meals."""

    BREAKFAST = "breakfast"
    LUNCH = "lunch"
    DINNER = "dinner"
    SNACK = "snack"


class DietEntryCreate(BaseModel):
    """Create a diet/meal entry."""

    meal_type: MealType
    description: Optional[str] = None
    photo_url: Optional[str] = None
    estimated_calories: Optional[float] = None
    macros: Optional[dict] = Field(
        default_factory=dict,
        description="Macronutrients: {protein, carbs, fats, fiber}",
    )
    ingredients: Optional[list[str]] = Field(default_factory=list)
    meal_quality_score: Optional[int] = Field(None, ge=1, le=5)
    logged_at: datetime


class DietEntryResponse(BaseModel):
    """Response model for diet entry."""

    id: str
    user_id: str
    meal_type: MealType
    description: Optional[str]
    photo_url: Optional[str]
    estimated_calories: Optional[float]
    macros: dict
    ingredients: list[str]
    meal_quality_score: Optional[int]
    logged_at: datetime
    created_at: datetime


class SubstanceType(str, Enum):
    """Types of substances to track."""

    ALCOHOL = "alcohol"
    CAFFEINE = "caffeine"
    CANNABIS = "cannabis"
    PRESCRIPTION = "prescription"
    SUPPLEMENT = "supplement"
    NICOTINE = "nicotine"
    OTHER = "other"


class SubstanceEntryCreate(BaseModel):
    """Create a substance entry."""

    substance_type: SubstanceType
    substance_name: Optional[str] = None
    quantity: float
    unit: str = Field(..., description="Unit of measurement (drinks, mg, cups, etc.)")
    notes: Optional[str] = None
    logged_at: datetime


class SubstanceEntryResponse(BaseModel):
    """Response model for substance entry."""

    id: str
    user_id: str
    substance_type: SubstanceType
    substance_name: Optional[str]
    quantity: float
    unit: str
    notes: Optional[str]
    logged_at: datetime
    created_at: datetime


class MoodEntryCreate(BaseModel):
    """Create a mood/stress entry."""

    mood_score: int = Field(..., ge=1, le=10, description="1 = very low, 10 = excellent")
    stress_level: Optional[int] = Field(None, ge=1, le=10)
    energy_level: Optional[int] = Field(None, ge=1, le=10)
    anxiety_level: Optional[int] = Field(None, ge=1, le=10)
    emotions: Optional[list[str]] = Field(
        default_factory=list,
        description="List of emotions: happy, sad, anxious, calm, etc.",
    )
    notes: Optional[str] = None
    logged_at: datetime


class MoodEntryResponse(BaseModel):
    """Response model for mood entry."""

    id: str
    user_id: str
    mood_score: int
    stress_level: Optional[int]
    energy_level: Optional[int]
    anxiety_level: Optional[int]
    emotions: list[str]
    notes: Optional[str]
    logged_at: datetime
    created_at: datetime


class NegativityType(str, Enum):
    """Types of negativity exposure."""

    NEWS = "news"
    SOCIAL_MEDIA = "social_media"
    CONFLICT = "conflict"
    WORK_STRESS = "work_stress"
    RELATIONSHIP = "relationship"
    OTHER = "other"


class NegativityEntryCreate(BaseModel):
    """Create a negativity exposure entry."""

    exposure_type: NegativityType
    intensity: int = Field(..., ge=1, le=10)
    duration_minutes: Optional[int] = None
    description: Optional[str] = None
    coping_strategy_used: Optional[str] = None
    logged_at: datetime


class NegativityEntryResponse(BaseModel):
    """Response model for negativity entry."""

    id: str
    user_id: str
    exposure_type: NegativityType
    intensity: int
    duration_minutes: Optional[int]
    description: Optional[str]
    coping_strategy_used: Optional[str]
    logged_at: datetime
    created_at: datetime


class GratitudeEntryCreate(BaseModel):
    """Create a gratitude entry."""

    gratitude_items: list[str] = Field(
        ...,
        min_length=1,
        max_length=10,
        description="List of things you're grateful for",
    )
    reflection: Optional[str] = None
    logged_at: datetime


class GratitudeEntryResponse(BaseModel):
    """Response model for gratitude entry."""

    id: str
    user_id: str
    gratitude_items: list[str]
    reflection: Optional[str]
    logged_at: datetime
    created_at: datetime


class MeditationType(str, Enum):
    """Types of meditation."""

    GUIDED = "guided"
    UNGUIDED = "unguided"
    BREATHING = "breathing"
    BODY_SCAN = "body_scan"
    LOVING_KINDNESS = "loving_kindness"
    VISUALIZATION = "visualization"
    OTHER = "other"


class MeditationSessionCreate(BaseModel):
    """Create a meditation session entry."""

    duration_minutes: int = Field(..., gt=0)
    meditation_type: Optional[MeditationType] = None
    guide_name: Optional[str] = None
    pre_session_mood: Optional[int] = Field(None, ge=1, le=10)
    post_session_mood: Optional[int] = Field(None, ge=1, le=10)
    notes: Optional[str] = None
    session_source: str = "manual"
    started_at: datetime


class MeditationSessionResponse(BaseModel):
    """Response model for meditation session."""

    id: str
    user_id: str
    duration_minutes: int
    meditation_type: Optional[MeditationType]
    guide_name: Optional[str]
    pre_session_mood: Optional[int]
    post_session_mood: Optional[int]
    notes: Optional[str]
    session_source: str
    started_at: datetime
    created_at: datetime
