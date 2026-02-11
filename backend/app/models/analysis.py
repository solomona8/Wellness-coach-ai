"""AI analysis data models."""

from __future__ import annotations
from datetime import date, datetime
from typing import Optional, List

from pydantic import BaseModel, Field


class WellnessScores(BaseModel):
    """Wellness scores across different categories."""

    sleep: int = Field(..., ge=0, le=100)
    activity: int = Field(..., ge=0, le=100)
    stress: int = Field(..., ge=0, le=100, description="Higher = better stress management")
    nutrition: int = Field(..., ge=0, le=100)
    mindfulness: int = Field(..., ge=0, le=100)
    overall: int = Field(..., ge=0, le=100)


class PatternDetection(BaseModel):
    """A detected pattern in user data."""

    pattern: str
    confidence: str = Field(..., pattern="^(high|medium|low)$")
    timeframe: str = Field(..., pattern="^(daily|weekly|monthly)$")


class CorrelationInsight(BaseModel):
    """A correlation between two factors."""

    factor1: str
    factor2: str
    relationship: str = Field(..., pattern="^(positive|negative)$")
    strength: str = Field(..., pattern="^(strong|moderate|weak)$")
    insight: str


class ActionItem(BaseModel):
    """A recommended action item."""

    priority: int = Field(..., ge=1, le=5)
    action: str
    rationale: str
    category: str = Field(
        ...,
        pattern="^(sleep|activity|nutrition|stress|mindfulness)$",
    )


class Recommendation(BaseModel):
    """A wellness recommendation."""

    type: str = Field(
        ...,
        pattern="^(sound_healing|meditation|exercise|sleep|nutrition)$",
    )
    suggestion: str
    timing: Optional[str] = None
    expected_benefit: Optional[str] = None


class Concern(BaseModel):
    """An area of concern flagged by analysis."""

    area: str
    severity: str = Field(..., pattern="^(low|medium|high)$")
    recommendation: str


class AnalysisRequest(BaseModel):
    """Request to generate analysis."""

    analysis_date: Optional[date] = Field(default=None, description="Defaults to yesterday")
    include_correlations: bool = True
    lookback_days: int = Field(7, ge=1, le=30)


class DailyAnalysisResponse(BaseModel):
    """Response model for daily analysis."""

    id: str
    user_id: str
    analysis_date: date
    summary: str
    key_insights: List[str]
    wellness_scores: WellnessScores
    detected_patterns: List[PatternDetection]
    correlations: List[CorrelationInsight]
    action_items: List[ActionItem]
    recommendations: List[Recommendation]
    concerns: Optional[List[Concern]] = None
    generated_at: datetime


class TrendData(BaseModel):
    """Trend data for a specific metric."""

    metric: str
    values: List[float]
    dates: List[date]
    trend_direction: str = Field(..., pattern="^(improving|declining|stable)$")
    change_percentage: float
