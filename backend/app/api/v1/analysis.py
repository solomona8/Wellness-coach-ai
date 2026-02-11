"""AI analysis endpoints."""

from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
import structlog

from app.models.analysis import (
    AnalysisRequest,
    DailyAnalysisResponse,
    TrendData,
)
from app.core.auth import get_current_user
from app.services.supabase import SupabaseService, get_supabase_service
from app.services.analysis_service import AnalysisService, get_analysis_service

router = APIRouter()
logger = structlog.get_logger()


@router.get("/daily/{analysis_date}", response_model=DailyAnalysisResponse)
async def get_daily_analysis(
    analysis_date: date,
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get the daily analysis for a specific date."""
    analysis = await supabase.get_daily_analysis(
        user_id=user["id"],
        analysis_date=analysis_date,
    )
    if not analysis:
        raise HTTPException(
            status_code=404,
            detail=f"No analysis found for {analysis_date}",
        )
    return analysis


@router.post("/generate", response_model=DailyAnalysisResponse)
async def generate_analysis(
    request: AnalysisRequest,
    background_tasks: BackgroundTasks,
    user: dict = Depends(get_current_user),
    analysis_service: AnalysisService = Depends(get_analysis_service),
):
    """Generate a new daily analysis."""
    # Default to yesterday if no date provided
    analysis_date = request.date or (date.today() - timedelta(days=1))

    try:
        analysis = await analysis_service.generate_daily_analysis(
            user_id=user["id"],
            analysis_date=analysis_date,
            lookback_days=request.lookback_days,
            include_correlations=request.include_correlations,
        )
        logger.info(
            "Generated daily analysis",
            user_id=user["id"],
            date=str(analysis_date),
        )
        return analysis
    except Exception as e:
        logger.error("Failed to generate analysis", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to generate analysis",
        )


@router.get("/trends", response_model=list[TrendData])
async def get_trends(
    metrics: list[str] = Query(
        default=["sleep_score", "mood_score", "hrv_avg"],
        description="Metrics to analyze trends for",
    ),
    days: int = Query(30, ge=7, le=90),
    user: dict = Depends(get_current_user),
    analysis_service: AnalysisService = Depends(get_analysis_service),
):
    """Get trend analysis for specified metrics."""
    trends = await analysis_service.analyze_trends(
        user_id=user["id"],
        metrics=metrics,
        days=days,
    )
    return trends


@router.get("/correlations", response_model=list[dict])
async def get_correlations(
    days: int = Query(30, ge=7, le=90),
    user: dict = Depends(get_current_user),
    analysis_service: AnalysisService = Depends(get_analysis_service),
):
    """Get correlation insights between different metrics."""
    correlations = await analysis_service.analyze_correlations(
        user_id=user["id"],
        days=days,
    )
    return correlations


@router.get("/patterns", response_model=list[dict])
async def get_patterns(
    days: int = Query(30, ge=7, le=90),
    user: dict = Depends(get_current_user),
    analysis_service: AnalysisService = Depends(get_analysis_service),
):
    """Get detected patterns in user behavior and metrics."""
    patterns = await analysis_service.detect_patterns(
        user_id=user["id"],
        days=days,
    )
    return patterns


@router.get("/history", response_model=list[DailyAnalysisResponse])
async def get_analysis_history(
    limit: int = Query(7, le=30),
    user: dict = Depends(get_current_user),
    supabase: SupabaseService = Depends(get_supabase_service),
):
    """Get recent analysis history."""
    analyses = await supabase.get_recent_analyses(
        user_id=user["id"],
        limit=limit,
    )
    return analyses
