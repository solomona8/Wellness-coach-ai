"""Health data endpoints for HealthKit integration."""

from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
import structlog

from app.models.health import (
    HealthMetricBatchCreate,
    HealthMetricResponse,
    SleepSessionCreate,
    SleepSessionResponse,
    ExerciseSessionCreate,
    ExerciseSessionResponse,
    MetricType,
)
from app.core.auth import get_current_user
from app.services.supabase import SupabaseService, get_supabase_service

router = APIRouter()
logger = structlog.get_logger()


@router.post("/metrics/batch", response_model=dict)
async def batch_upload_metrics(
    data: HealthMetricBatchCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Batch upload health metrics from iOS HealthKit."""
    try:
        result = await supabase.batch_insert_health_metrics(
            user_id=user["id"],
            metrics=[m.model_dump() for m in data.metrics],
            device_id=data.device_id,
        )
        logger.info(
            "Batch uploaded health metrics",
            user_id=user["id"],
            count=len(data.metrics),
        )
        return {"synced": len(result), "device_id": data.device_id}
    except Exception as e:
        logger.error("Failed to batch upload metrics", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to upload metrics")


@router.get("/metrics", response_model=list[HealthMetricResponse])
async def get_health_metrics(
    metric_type: Optional[MetricType] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    limit: int = Query(100, le=1000),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get health metrics with optional filtering."""
    metrics = await supabase.get_health_metrics(
        user_id=user["id"],
        metric_type=metric_type,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
        offset=offset,
    )
    return metrics


@router.get("/metrics/summary", response_model=dict)
async def get_metrics_summary(
    date: date = Query(..., description="Date for summary"),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get summarized health metrics for a specific date."""
    summary = await supabase.get_health_summary(user_id=user["id"], date=date)
    return summary


@router.post("/sleep", response_model=SleepSessionResponse)
async def upload_sleep_session(
    data: SleepSessionCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Upload a sleep session."""
    # Calculate total duration
    total_minutes = int((data.end_time - data.start_time).total_seconds() / 60)

    # Calculate sleep score
    sleep_score = calculate_sleep_score(data, total_minutes)

    session = await supabase.insert_sleep_session(
        user_id=user["id"],
        data={
            **data.model_dump(),
            "total_duration_minutes": total_minutes,
            "sleep_score": sleep_score,
        },
    )
    logger.info("Uploaded sleep session", user_id=user["id"], duration=total_minutes)
    return session


@router.get("/sleep", response_model=list[SleepSessionResponse])
async def get_sleep_sessions(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    limit: int = Query(30, le=100),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get sleep session history."""
    sessions = await supabase.get_sleep_sessions(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )
    return sessions


@router.post("/exercise", response_model=ExerciseSessionResponse)
async def upload_exercise_session(
    data: ExerciseSessionCreate,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Upload an exercise session."""
    session = await supabase.insert_exercise_session(
        user_id=user["id"],
        data=data.model_dump(),
    )
    logger.info(
        "Uploaded exercise session",
        user_id=user["id"],
        type=data.exercise_type,
        duration=data.duration_minutes,
    )
    return session


@router.get("/exercise", response_model=list[ExerciseSessionResponse])
async def get_exercise_sessions(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    limit: int = Query(30, le=100),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get exercise session history."""
    sessions = await supabase.get_exercise_sessions(
        user_id=user["id"],
        start_date=start_date,
        end_date=end_date,
        limit=limit,
    )
    return sessions


def calculate_sleep_score(data: SleepSessionCreate, total_minutes: int) -> float:
    """Calculate a sleep quality score (0-100)."""
    if total_minutes == 0:
        return 0.0

    score = 0.0

    # Duration component (max 40 points) - optimal is 420-540 minutes (7-9 hours)
    if 420 <= total_minutes <= 540:
        score += 40
    elif total_minutes < 420:
        score += max(0, 40 * (total_minutes / 420))
    else:
        score += max(0, 40 - (total_minutes - 540) * 0.1)

    # Sleep stages component (max 60 points)
    if data.deep_sleep_minutes is not None and data.rem_sleep_minutes is not None:
        # Deep sleep should be 13-23% of total (optimal ~20%)
        deep_pct = data.deep_sleep_minutes / total_minutes * 100 if total_minutes else 0
        if 13 <= deep_pct <= 23:
            score += 20
        else:
            score += max(0, 20 - abs(18 - deep_pct) * 2)

        # REM should be 20-25% of total (optimal ~22%)
        rem_pct = data.rem_sleep_minutes / total_minutes * 100 if total_minutes else 0
        if 20 <= rem_pct <= 25:
            score += 20
        else:
            score += max(0, 20 - abs(22.5 - rem_pct) * 2)

        # Awake time penalty
        if data.awake_minutes is not None:
            awake_pct = data.awake_minutes / total_minutes * 100 if total_minutes else 0
            score += max(0, 20 - awake_pct * 2)
        else:
            score += 10
    else:
        # If no sleep stage data, give average score
        score += 30

    return min(100, max(0, round(score, 1)))
