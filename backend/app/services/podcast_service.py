"""Podcast generation service using ElevenLabs."""

from datetime import date, datetime, timedelta
from typing import Optional

from elevenlabs import ElevenLabs
from fastapi import Depends
import structlog

from app.config import Settings, get_settings
from app.services.supabase import SupabaseService, get_supabase_service
from app.services.analysis_service import AnalysisService, get_analysis_service
from app.services.storage import StorageService, get_storage_service

logger = structlog.get_logger()


class PodcastService:
    """Service for generating personalized daily podcasts."""

    def __init__(
        self,
        settings: Settings,
        supabase: SupabaseService,
        analysis_service: AnalysisService,
        storage: StorageService,
    ):
        self.elevenlabs = ElevenLabs(api_key=settings.elevenlabs_api_key)
        self.default_voice_id = settings.elevenlabs_default_voice_id
        self.supabase = supabase
        self.analysis_service = analysis_service
        self.storage = storage

    async def generate_daily_podcast(
        self,
        user_id: str,
        podcast_date: date,
    ) -> dict:
        """Generate personalized daily podcast."""
        # Get or generate analysis
        analysis = await self._get_or_generate_analysis(user_id, podcast_date)

        # Get user preferences
        profile = await self.supabase.get_user_profile(user_id)
        voice_id = profile.get("voice_preference") if profile else None

        # Use default voice if no valid ElevenLabs voice ID is set
        # ElevenLabs voice IDs are typically 20+ character alphanumeric strings
        if not voice_id or voice_id == "default" or len(voice_id) < 20:
            voice_id = self.default_voice_id

        display_name = profile.get("display_name", "friend") if profile else "friend"

        # Generate script
        script = self._generate_script(analysis, display_name)

        # Generate TLDR with action items
        tldr = self._generate_tldr(analysis)

        # Generate audio
        audio_data = await self._generate_audio(script, voice_id)

        # Store audio
        audio_url = await self._store_audio(user_id, podcast_date, audio_data)

        # Estimate duration (roughly 150 words per minute)
        word_count = len(script.split())
        duration_seconds = int((word_count / 150) * 60)

        # Create podcast record
        podcast = await self.supabase.insert_podcast({
            "user_id": user_id,
            "analysis_id": analysis.get("id"),
            "podcast_date": podcast_date.isoformat(),
            "title": f"Your Wellness Briefing - {podcast_date.strftime('%B %d')}",
            "script": script,
            "tldr": tldr,
            "audio_url": audio_url,
            "duration_seconds": duration_seconds,
            "voice_id": voice_id,
        })

        logger.info(
            "Generated podcast",
            user_id=user_id,
            date=str(podcast_date),
            duration=duration_seconds,
        )

        return podcast

    async def _get_or_generate_analysis(
        self,
        user_id: str,
        podcast_date: date,
    ) -> dict:
        """Get existing analysis or generate new one."""
        # Look for yesterday's analysis (podcast is about yesterday)
        analysis_date = podcast_date - timedelta(days=1)

        analysis = await self.supabase.get_daily_analysis(user_id, analysis_date)

        if not analysis:
            analysis = await self.analysis_service.generate_daily_analysis(
                user_id=user_id,
                analysis_date=analysis_date,
            )

        return analysis

    def _generate_script(self, analysis: dict, name: str) -> str:
        """Generate podcast script from analysis."""
        wellness_scores = analysis.get("wellness_scores", {})
        insights = analysis.get("key_insights", [])
        action_items = analysis.get("action_items", [])
        patterns = analysis.get("detected_patterns", [])
        recommendations = analysis.get("recommendations", [])

        # Build script sections
        greeting = f"Good morning, {name}! This is your personalized wellness briefing for today."

        # Wellness summary
        overall = wellness_scores.get("overall", 50)
        if overall >= 80:
            summary_opener = "Great news! You had an excellent day yesterday."
        elif overall >= 60:
            summary_opener = "You had a solid day yesterday with some room for growth."
        elif overall >= 40:
            summary_opener = "Yesterday had its challenges, but today is a fresh opportunity."
        else:
            summary_opener = "Yesterday was tough, but remember: every day is a chance to reset."

        wellness_summary = self._format_wellness_summary(wellness_scores, summary_opener)

        # Insights section
        insights_section = self._format_insights(insights)

        # Patterns section
        patterns_section = self._format_patterns(patterns)

        # Action items
        actions_section = self._format_actions(action_items)

        # Recommendations
        recs_section = self._format_recommendations(recommendations)

        # Closing
        closing = self._generate_closing(wellness_scores)

        # Assemble script
        script = f"""{greeting}

{wellness_summary}

{insights_section}

{patterns_section}

{actions_section}

{recs_section}

{closing}

Have an amazing day, {name}! Remember, every small step counts on your wellness journey.
"""
        return script

    def _format_wellness_summary(self, scores: dict, opener: str) -> str:
        """Format wellness scores into conversational text."""
        parts = [opener]

        sleep = scores.get("sleep", 0)
        activity = scores.get("activity", 0)
        stress = scores.get("stress", 0)

        if sleep >= 70:
            parts.append("Your sleep was restorative")
        elif sleep >= 50:
            parts.append("Your sleep was decent")
        else:
            parts.append("Your sleep could use some attention")

        if activity >= 70:
            parts.append("and you were very active")
        elif activity >= 50:
            parts.append("and you got some good movement in")
        else:
            parts.append("Today might be a good day to move your body")

        if stress >= 70:
            parts.append("Your stress levels were well managed.")
        elif stress >= 50:
            parts.append("Your stress levels were moderate.")
        else:
            parts.append("Consider some stress relief activities today.")

        return " ".join(parts)

    def _format_insights(self, insights: list) -> str:
        """Format insights into conversational text."""
        if not insights:
            return ""

        section = "Here are your key insights from yesterday:\n\n"
        for i, insight in enumerate(insights[:3], 1):
            section += f"Number {i}: {insight}\n\n"

        return section

    def _format_patterns(self, patterns: list) -> str:
        """Format patterns into conversational text."""
        if not patterns:
            return ""

        high_confidence = [p for p in patterns if p.get("confidence") == "high"]
        if not high_confidence:
            return ""

        section = "I've noticed some patterns in your data:\n\n"
        for pattern in high_confidence[:2]:
            section += f"{pattern.get('pattern')}\n\n"

        return section

    def _format_actions(self, actions: list) -> str:
        """Format action items into conversational text."""
        if not actions:
            return ""

        section = "For today, I recommend focusing on these actions:\n\n"

        # Sort by priority
        sorted_actions = sorted(actions, key=lambda x: x.get("priority", 5))

        for action in sorted_actions[:3]:
            section += f"{action.get('action')}. {action.get('rationale', '')}\n\n"

        return section

    def _format_recommendations(self, recommendations: list) -> str:
        """Format recommendations into conversational text."""
        if not recommendations:
            return ""

        section = "Here are some personalized recommendations:\n\n"

        for rec in recommendations[:2]:
            timing = rec.get("timing", "")
            timing_str = f" {timing}" if timing else ""
            section += f"{rec.get('suggestion')}.{timing_str}\n\n"

        return section

    def _generate_closing(self, scores: dict) -> str:
        """Generate motivational closing based on scores."""
        overall = scores.get("overall", 50)

        if overall >= 80:
            return "You're doing fantastic! Keep up the great work and maintain this positive momentum."
        elif overall >= 60:
            return "You're on the right track. Focus on your action items today and you'll see continued improvement."
        elif overall >= 40:
            return "Remember, wellness is a journey, not a destination. Small consistent steps lead to big changes."
        else:
            return "Today is a new day with new possibilities. Be gentle with yourself and focus on one small improvement."

    def _generate_tldr(self, analysis: dict) -> str:
        """Generate a TLDR summary with action items."""
        wellness_scores = analysis.get("wellness_scores", {})
        action_items = analysis.get("action_items", [])
        key_insights = analysis.get("key_insights", [])

        # Overall score summary
        overall = wellness_scores.get("overall", 50)
        if overall >= 80:
            score_summary = f"🌟 Wellness Score: {overall}/100 - Excellent!"
        elif overall >= 60:
            score_summary = f"✅ Wellness Score: {overall}/100 - Good"
        elif overall >= 40:
            score_summary = f"📊 Wellness Score: {overall}/100 - Room to improve"
        else:
            score_summary = f"💪 Wellness Score: {overall}/100 - Focus on recovery"

        # Build TLDR sections
        tldr_parts = [score_summary, ""]

        # Key insight (just the top one)
        if key_insights:
            tldr_parts.append(f"💡 Key Insight: {key_insights[0]}")
            tldr_parts.append("")

        # Action items as bullet points
        if action_items:
            tldr_parts.append("📋 Today's Actions:")
            # Sort by priority and take top 3
            sorted_actions = sorted(action_items, key=lambda x: x.get("priority", 5))[:3]
            for action in sorted_actions:
                action_text = action.get("action", "")
                tldr_parts.append(f"• {action_text}")

        return "\n".join(tldr_parts)

    async def _generate_audio(self, script: str, voice_id: str) -> bytes:
        """Generate audio using ElevenLabs."""
        audio_generator = self.elevenlabs.text_to_speech.convert(
            voice_id=voice_id,
            text=script,
            model_id="eleven_multilingual_v2",
            output_format="mp3_44100_128",
        )

        # Collect audio chunks
        audio_data = b""
        for chunk in audio_generator:
            audio_data += chunk

        return audio_data

    async def _store_audio(
        self,
        user_id: str,
        podcast_date: date,
        audio_data: bytes,
    ) -> Optional[str]:
        """Store podcast audio in storage."""
        path = f"podcasts/{user_id}/{podcast_date.isoformat()}.mp3"

        try:
            url = await self.storage.upload_audio(
                bucket="Audio",  # Capital A to match Supabase bucket name
                path=path,
                data=audio_data,
                content_type="audio/mpeg",
            )
            return url
        except Exception as e:
            logger.warning(
                "Failed to upload audio to storage, podcast will be saved without audio URL",
                error=str(e),
            )
            return None


def get_podcast_service(
    settings: Settings = Depends(get_settings),
    supabase: SupabaseService = Depends(get_supabase_service),
    analysis_service: AnalysisService = Depends(get_analysis_service),
    storage: StorageService = Depends(get_storage_service),
) -> PodcastService:
    """Get podcast service instance."""
    return PodcastService(settings, supabase, analysis_service, storage)
