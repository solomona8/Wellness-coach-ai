"""Health data models for HealthKit integration."""

from __future__ import annotations
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any

from pydantic import BaseModel, Field


class MetricType(str, Enum):
    """Types of health metrics from HealthKit."""

    HEART_RATE = "heart_rate"
    HRV = "hrv"
    GLUCOSE = "glucose"
    MINDFULNESS = "mindfulness"
    ACTIVE_ENERGY = "active_energy"
    EXERCISE_TIME = "exercise_time"


class ExerciseType(str, Enum):
    """Exercise intensity categories."""

    VIGOROUS = "vigorous"
    MODERATE = "moderate"
    LIGHT = "light"
    RESISTANCE = "resistance"
    FLEXIBILITY = "flexibility"


class HealthMetricCreate(BaseModel):
    """Create a single health metric entry."""

    metric_type: MetricType
    value: float
    unit: str
    metadata: Optional[dict] = Field(default_factory=dict)
    recorded_at: datetime
    source: str = "healthkit"


class HealthMetricResponse(BaseModel):
    """Response model for health metric."""

    id: str
    user_id: str
    metric_type: MetricType
    value: float
    unit: str
    metadata: dict
    source: str
    recorded_at: datetime
    synced_at: datetime


class HealthMetricBatchCreate(BaseModel):
    """Batch upload of health metrics from iOS."""

    metrics: List[HealthMetricCreate]
    device_id: str


class SleepSessionCreate(BaseModel):
    """Create a sleep session entry."""

    start_time: datetime
    end_time: datetime
    deep_sleep_minutes: Optional[int] = None
    rem_sleep_minutes: Optional[int] = None
    light_sleep_minutes: Optional[int] = None
    awake_minutes: Optional[int] = None
    raw_data: Optional[dict] = Field(default_factory=dict)
    source: str = "healthkit"


class SleepSessionResponse(BaseModel):
    """Response model for sleep session."""

    id: str
    user_id: str
    start_time: datetime
    end_time: datetime
    total_duration_minutes: int
    deep_sleep_minutes: Optional[int]
    rem_sleep_minutes: Optional[int]
    light_sleep_minutes: Optional[int]
    awake_minutes: Optional[int]
    sleep_score: Optional[float]
    source: str
    created_at: datetime


class ExerciseSessionCreate(BaseModel):
    """Create an exercise session entry."""

    exercise_type: ExerciseType
    activity_name: Optional[str] = None
    duration_minutes: int = Field(..., gt=0)
    calories_burned: Optional[float] = None
    heart_rate_avg: Optional[float] = None
    heart_rate_max: Optional[float] = None
    metadata: Optional[dict] = Field(default_factory=dict)
    started_at: datetime
    ended_at: Optional[datetime] = None
    source: str = "healthkit"


class ExerciseSessionResponse(BaseModel):
    """Response model for exercise session."""

    id: str
    user_id: str
    exercise_type: ExerciseType
    activity_name: Optional[str]
    duration_minutes: int
    calories_burned: Optional[float]
    heart_rate_avg: Optional[float]
    heart_rate_max: Optional[float]
    metadata: dict
    started_at: datetime
    ended_at: Optional[datetime]
    source: str
    created_at: datetime
