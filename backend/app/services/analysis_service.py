"""AI analysis service using Claude."""

from datetime import date, datetime, timedelta
from typing import Optional
import json

from anthropic import Anthropic
from fastapi import Depends
import structlog

from app.config import Settings, get_settings
from app.services.supabase import SupabaseService, get_supabase_service

logger = structlog.get_logger()


class AnalysisService:
    """Service for AI-powered wellness analysis."""

    def __init__(self, settings: Settings, supabase: SupabaseService):
        self.claude = Anthropic(api_key=settings.anthropic_api_key)
        self.model = settings.claude_model
        self.supabase = supabase

    async def generate_daily_analysis(
        self,
        user_id: str,
        analysis_date: date,
        lookback_days: int = 7,
        include_correlations: bool = True,
    ) -> dict:
        """Generate comprehensive daily analysis using Claude."""
        # Gather all user data
        user_data = await self._gather_user_data(user_id, analysis_date, lookback_days)

        # Build analysis prompt
        prompt = self._build_analysis_prompt(user_data, analysis_date)

        # Call Claude
        response = await self._call_claude(prompt)

        # Parse response
        analysis = self._parse_response(response)

        # Store analysis
        stored = await self.supabase.upsert_daily_analysis({
            "user_id": user_id,
            "analysis_date": analysis_date.isoformat(),
            "summary": analysis.get("summary", ""),
            "key_insights": analysis.get("key_insights", []),
            "action_items": analysis.get("action_items", []),
            "detected_patterns": analysis.get("detected_patterns", []),
            "correlations": analysis.get("correlations", []),
            "wellness_scores": analysis.get("wellness_scores", {}),
            "recommendations": analysis.get("recommendations", []),
            "concerns": analysis.get("concerns", []),
            "raw_claude_response": {"response": response},
        })

        logger.info("Generated daily analysis", user_id=user_id, date=str(analysis_date))
        return stored

    async def _gather_user_data(
        self,
        user_id: str,
        analysis_date: date,
        lookback_days: int,
    ) -> dict:
        """Gather all relevant user data for analysis."""
        start_date = analysis_date - timedelta(days=lookback_days)

        return {
            "user_profile": await self.supabase.get_user_profile(user_id),
            "health_metrics": await self.supabase.get_health_metrics(
                user_id, start_date=start_date, end_date=analysis_date, limit=1000
            ),
            "sleep_sessions": await self.supabase.get_sleep_sessions(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "exercise_sessions": await self.supabase.get_exercise_sessions(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "diet_entries": await self.supabase.get_diet_entries(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "substance_entries": await self.supabase.get_substance_entries(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "mood_entries": await self.supabase.get_mood_entries(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "negativity_entries": await self.supabase.get_negativity_entries(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "gratitude_entries": await self.supabase.get_gratitude_entries(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "meditation_sessions": await self.supabase.get_meditation_sessions(
                user_id, start_date=start_date, end_date=analysis_date
            ),
            "previous_analyses": await self.supabase.get_recent_analyses(user_id, limit=3),
        }

    def _build_analysis_prompt(self, user_data: dict, analysis_date: date) -> str:
        """Build the analysis prompt for Claude."""
        # analysis_date is already the target day (podcast_date - 1 from podcast_service),
        # so use it directly — do NOT subtract another day.
        target_date = analysis_date

        # Format data sections
        sleep_data = self._format_sleep(user_data.get("sleep_sessions", []), target_date)
        heart_data = self._format_heart_metrics(user_data.get("health_metrics", []), target_date)
        exercise_data = self._format_exercise(user_data.get("exercise_sessions", []), target_date)
        diet_data = self._format_diet(user_data.get("diet_entries", []), target_date)
        mood_data = self._format_mood(user_data.get("mood_entries", []), target_date)
        substance_data = self._format_substances(user_data.get("substance_entries", []), target_date)
        negativity_data = self._format_negativity(user_data.get("negativity_entries", []), target_date)
        mindfulness_data = self._format_mindfulness(user_data, target_date)

        profile = user_data.get("user_profile") or {}
        health_goals = json.dumps(profile.get("health_goals", []))

        return f"""You are a wellness coach AI analyzing health data for a user.
Today's date is {analysis_date.isoformat()}. Analyze the following data and provide insights.

## User Profile
- Health Goals: {health_goals}
- Timezone: {profile.get("timezone", "UTC")}

## Data for {target_date.isoformat()}

### Sleep
{sleep_data}

### Heart Rate & HRV
{heart_data}

### Exercise
{exercise_data}

### Diet
{diet_data}

### Mood & Stress
{mood_data}

### Substances (Alcohol, Caffeine, etc.)
{substance_data}

### Negativity Exposure
{negativity_data}

### Gratitude & Meditation
{mindfulness_data}

---

Please provide analysis in this JSON format:
{{
    "summary": "2-3 sentence summary of yesterday's wellness",
    "key_insights": ["Insight 1", "Insight 2", "Insight 3"],
    "wellness_scores": {{
        "sleep": 0-100,
        "activity": 0-100,
        "stress": 0-100,
        "nutrition": 0-100,
        "mindfulness": 0-100,
        "overall": 0-100
    }},
    "detected_patterns": [
        {{"pattern": "description", "confidence": "high/medium/low", "timeframe": "daily/weekly"}}
    ],
    "correlations": [
        {{"factor1": "X", "factor2": "Y", "relationship": "positive/negative", "strength": "strong/moderate/weak", "insight": "explanation"}}
    ],
    "action_items": [
        {{"priority": 1, "action": "specific action", "rationale": "why", "category": "sleep/activity/nutrition/stress/mindfulness"}}
    ],
    "recommendations": [
        {{"type": "sound_healing/meditation/exercise/sleep/nutrition", "suggestion": "specific suggestion", "timing": "when", "expected_benefit": "benefit"}}
    ],
    "concerns": [
        {{"area": "area of concern", "severity": "low/medium/high", "recommendation": "what to do"}}
    ]
}}

Be encouraging but honest. Focus on actionable insights."""

    async def _call_claude(self, prompt: str) -> str:
        """Call Claude API for analysis."""
        response = self.claude.messages.create(
            model=self.model,
            max_tokens=4096,
            system="You are an expert wellness coach. Analyze health data and provide actionable insights. Always respond with valid JSON.",
            messages=[{"role": "user", "content": prompt}],
        )
        return response.content[0].text

    def _parse_response(self, response: str) -> dict:
        """Parse Claude's JSON response."""
        # Handle markdown code blocks
        if "```json" in response:
            response = response.split("```json")[1].split("```")[0]
        elif "```" in response:
            response = response.split("```")[1].split("```")[0]

        try:
            return json.loads(response.strip())
        except json.JSONDecodeError as e:
            logger.error("Failed to parse Claude response", error=str(e))
            return {
                "summary": "Analysis could not be parsed",
                "key_insights": [],
                "wellness_scores": {"overall": 50},
                "action_items": [],
            }

    # Data formatting helpers
    def _format_sleep(self, sessions: list, target_date: date) -> str:
        """Format sleep data for prompt."""
        target_sessions = [
            s for s in sessions
            if s.get("start_time", "").startswith(target_date.isoformat())
        ]

        if not target_sessions:
            return "No sleep data recorded"

        session = target_sessions[0]
        deep = session.get('deep_sleep_minutes', 0) or 0
        rem = session.get('rem_sleep_minutes', 0) or 0
        light = session.get('light_sleep_minutes', 0) or 0
        awake = session.get('awake_minutes', 0) or 0
        total_sleep = deep + rem + light

        return f"""- Total Sleep Time: {total_sleep} minutes ({total_sleep / 60:.1f} hours)
- Deep Sleep: {deep} minutes
- REM Sleep: {rem} minutes
- Light Sleep: {light} minutes
- Awake: {awake} minutes
- Sleep Score: {session.get('sleep_score', 'N/A')}"""

    def _format_heart_metrics(self, metrics: list, target_date: date) -> str:
        """Format heart rate and HRV data."""
        target_str = target_date.isoformat()
        hr = [m["value"] for m in metrics if m.get("metric_type") == "heart_rate" and target_str in m.get("recorded_at", "")]
        hrv = [m["value"] for m in metrics if m.get("metric_type") == "hrv" and target_str in m.get("recorded_at", "")]

        hr_avg = sum(hr) / len(hr) if hr else None
        hrv_avg = sum(hrv) / len(hrv) if hrv else None

        return f"""- Average Heart Rate: {f'{hr_avg:.1f} bpm' if hr_avg else 'N/A'}
- Average HRV: {f'{hrv_avg:.1f} ms' if hrv_avg else 'N/A'}
- HR Data Points: {len(hr)}
- HRV Data Points: {len(hrv)}"""

    def _format_exercise(self, sessions: list, target_date: date) -> str:
        """Format exercise data."""
        target_str = target_date.isoformat()
        yesterday = [s for s in sessions if target_str in s.get("started_at", "")]

        if not yesterday:
            return "No exercise recorded"

        lines = []
        total_minutes = 0
        for s in yesterday:
            lines.append(f"- {s.get('activity_name', s.get('exercise_type'))}: {s.get('duration_minutes')} min")
            total_minutes += s.get("duration_minutes", 0)

        lines.insert(0, f"Total: {total_minutes} minutes")
        return "\n".join(lines)

    def _format_diet(self, entries: list, target_date: date) -> str:
        """Format diet data."""
        target_str = target_date.isoformat()
        yesterday = [e for e in entries if target_str in e.get("logged_at", "")]

        if not yesterday:
            return "No meals logged"

        lines = []
        total_cals = 0
        for e in yesterday:
            cals = e.get("estimated_calories", 0) or 0
            total_cals += cals
            lines.append(f"- {e.get('meal_type')}: {e.get('description', 'No description')} ({cals} cal)")

        lines.insert(0, f"Total Calories: ~{total_cals}")
        return "\n".join(lines)

    def _format_mood(self, entries: list, target_date: date) -> str:
        """Format mood data."""
        target_str = target_date.isoformat()
        yesterday = [e for e in entries if target_str in e.get("logged_at", "")]

        if not yesterday:
            return "No mood data logged"

        moods = [e.get("mood_score", 0) for e in yesterday]
        stress = [e.get("stress_level", 0) for e in yesterday if e.get("stress_level")]

        return f"""- Average Mood: {sum(moods)/len(moods):.1f}/10
- Average Stress: {sum(stress)/len(stress):.1f}/10 if stress else 'N/A'
- Entries: {len(yesterday)}"""

    def _format_substances(self, entries: list, target_date: date) -> str:
        """Format substance data."""
        target_str = target_date.isoformat()
        yesterday = [e for e in entries if target_str in e.get("logged_at", "")]

        if not yesterday:
            return "None logged"

        lines = []
        for e in yesterday:
            lines.append(f"- {e.get('substance_type')}: {e.get('quantity')} {e.get('unit')}")

        return "\n".join(lines)

    def _format_negativity(self, entries: list, target_date: date) -> str:
        """Format negativity exposure data."""
        target_str = target_date.isoformat()
        yesterday = [e for e in entries if target_str in e.get("logged_at", "")]

        if not yesterday:
            return "None logged"

        lines = []
        for e in yesterday:
            lines.append(f"- {e.get('exposure_type')}: intensity {e.get('intensity')}/10")

        return "\n".join(lines)

    def _format_mindfulness(self, user_data: dict, target_date: date) -> str:
        """Format gratitude and meditation data."""
        target_str = target_date.isoformat()

        gratitude = [e for e in user_data.get("gratitude_entries", []) if target_str in e.get("logged_at", "")]
        meditation = [s for s in user_data.get("meditation_sessions", []) if target_str in s.get("started_at", "")]

        lines = []
        if gratitude:
            items = gratitude[0].get("gratitude_items", [])
            lines.append(f"- Gratitude items: {len(items)}")
        else:
            lines.append("- No gratitude logged")

        if meditation:
            total_mins = sum(s.get("duration_minutes", 0) for s in meditation)
            lines.append(f"- Meditation: {total_mins} total minutes")
        else:
            lines.append("- No meditation logged")

        return "\n".join(lines)

    async def analyze_trends(
        self,
        user_id: str,
        metrics: list[str],
        days: int,
    ) -> list[dict]:
        """Analyze trends for specified metrics."""
        # Implementation for trend analysis
        # This would calculate trends over time for each metric
        return []

    async def analyze_correlations(self, user_id: str, days: int) -> list[dict]:
        """Analyze correlations between metrics."""
        # Implementation for correlation analysis
        return []

    async def detect_patterns(self, user_id: str, days: int) -> list[dict]:
        """Detect patterns in user behavior."""
        # Implementation for pattern detection
        return []


def get_analysis_service(
    settings: Settings = Depends(get_settings),
    supabase: SupabaseService = Depends(get_supabase_service),
) -> AnalysisService:
    """Get analysis service instance."""
    return AnalysisService(settings, supabase)
