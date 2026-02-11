"""Sound healing service with dynamic generation."""

from typing import Optional
import io

from fastapi import Depends
import numpy as np
from scipy.io import wavfile
import structlog

from app.config import Settings, get_settings
from app.services.supabase import SupabaseService, get_supabase_service
from app.services.storage import StorageService, get_storage_service

logger = structlog.get_logger()


class SoundHealingService:
    """Service for sound healing recommendations and dynamic generation."""

    # Solfeggio frequencies
    SOLFEGGIO = {
        174: "pain_relief",
        285: "healing",
        396: "liberation",
        417: "change",
        528: "transformation",
        639: "connection",
        741: "expression",
        852: "intuition",
        963: "enlightenment",
    }

    # Brainwave frequency ranges
    BRAINWAVES = {
        "delta": (0.5, 4),    # Deep sleep
        "theta": (4, 8),      # Meditation
        "alpha": (8, 12),     # Relaxation
        "beta": (12, 30),     # Focus
        "gamma": (30, 100),   # Peak performance
    }

    # Target state to brainwave mapping
    STATE_BRAINWAVE = {
        "sleep": "delta",
        "deep_sleep": "delta",
        "meditation": "theta",
        "relaxation": "alpha",
        "focus": "beta",
        "energy": "beta",
        "stress_relief": "alpha",
        "healing": "theta",
    }

    def __init__(
        self,
        settings: Settings,
        supabase: SupabaseService,
        storage: StorageService,
    ):
        self.supabase = supabase
        self.storage = storage

    async def get_recommendations(
        self,
        user_id: str,
        current_state: Optional[dict] = None,
    ) -> list[dict]:
        """Get personalized sound healing recommendations."""
        # Get user's recent metrics
        user_metrics = await self._get_user_metrics(user_id)

        # Assess needs
        needs = self._assess_needs(user_metrics, current_state)

        # Get matching tracks
        tracks = await self.supabase.get_sound_tracks(
            target_state=needs["primary_state"],
            limit=10,
        )

        # Build recommendations
        recommendations = []

        for track in tracks[:5]:
            recommendations.append({
                "track": track,
                "type": "library",
                "reason": self._get_recommendation_reason(track, needs),
                "priority": self._calculate_priority(track, needs),
            })

        # Add dynamic option if appropriate
        if needs.get("suggest_dynamic"):
            dynamic_params = self._get_dynamic_params(needs)
            recommendations.append({
                "track": None,
                "type": "dynamic",
                "reason": "Custom-generated frequencies tailored to your current state",
                "priority": 10,
                "dynamic_params": dynamic_params,
            })

        return sorted(recommendations, key=lambda x: x["priority"], reverse=True)

    async def _get_user_metrics(self, user_id: str) -> dict:
        """Get relevant recent metrics for the user."""
        metrics = await self.supabase.get_health_metrics(
            user_id=user_id,
            limit=100,
        )

        # Get latest HRV
        hrv_metrics = [m for m in metrics if m.get("metric_type") == "hrv"]
        latest_hrv = hrv_metrics[0]["value"] if hrv_metrics else None

        # Get recent mood
        mood_entries = await self.supabase.get_mood_entries(user_id=user_id, limit=3)
        latest_mood = mood_entries[0].get("mood_score") if mood_entries else None
        latest_stress = mood_entries[0].get("stress_level") if mood_entries else None

        # Get recent sleep
        sleep_sessions = await self.supabase.get_sleep_sessions(user_id=user_id, limit=1)
        last_sleep_score = sleep_sessions[0].get("sleep_score") if sleep_sessions else None

        return {
            "latest_hrv": latest_hrv,
            "latest_mood": latest_mood,
            "latest_stress": latest_stress,
            "last_sleep_score": last_sleep_score,
        }

    def _assess_needs(
        self,
        metrics: dict,
        current_state: Optional[dict],
    ) -> dict:
        """Assess user's needs based on metrics and state."""
        needs = {
            "primary_state": "relaxation",
            "secondary_states": [],
            "suggest_dynamic": False,
            "urgency": "normal",
        }

        hrv = metrics.get("latest_hrv")
        stress = metrics.get("latest_stress")
        mood = metrics.get("latest_mood")
        sleep_score = metrics.get("last_sleep_score")

        # Low HRV indicates stress
        if hrv and hrv < 30:
            needs["primary_state"] = "stress_relief"
            needs["suggest_dynamic"] = True
            needs["urgency"] = "high"

        # High stress level
        if stress and stress > 7:
            needs["primary_state"] = "stress_relief"
            needs["secondary_states"].append("relaxation")
            needs["urgency"] = "high"

        # Low mood
        if mood and mood < 5:
            needs["secondary_states"].append("healing")

        # Poor sleep
        if sleep_score and sleep_score < 60:
            needs["secondary_states"].append("sleep")

        # Consider time of day
        if current_state:
            time_of_day = current_state.get("time_of_day")
            if time_of_day == "evening" or time_of_day == "night":
                needs["primary_state"] = "sleep"
            elif time_of_day == "morning":
                needs["secondary_states"].append("energy")

        return needs

    def _get_recommendation_reason(self, track: dict, needs: dict) -> str:
        """Generate recommendation reason."""
        target = track.get("target_state", "")
        category = track.get("category", "")

        reasons = {
            "sleep": "to help you prepare for restful sleep",
            "relaxation": "to help you unwind and relax",
            "focus": "to enhance your concentration",
            "meditation": "to deepen your meditation practice",
            "stress_relief": "to reduce stress and anxiety",
            "healing": "to support your body's natural healing",
            "energy": "to boost your energy levels",
        }

        base = reasons.get(target, "for your wellness")

        if needs.get("urgency") == "high":
            return f"Highly recommended {base} based on your current stress levels"

        return f"Recommended {base}"

    def _calculate_priority(self, track: dict, needs: dict) -> int:
        """Calculate recommendation priority."""
        priority = 5

        # Match primary state
        if track.get("target_state") == needs.get("primary_state"):
            priority += 3

        # Match secondary states
        if track.get("target_state") in needs.get("secondary_states", []):
            priority += 2

        # Urgency boost
        if needs.get("urgency") == "high":
            priority += 2

        # Popularity factor
        popularity = track.get("popularity_score", 0)
        if popularity > 80:
            priority += 1

        return min(priority, 10)

    def _get_dynamic_params(self, needs: dict) -> dict:
        """Get parameters for dynamic sound generation."""
        state = needs.get("primary_state", "relaxation")
        brainwave = self.STATE_BRAINWAVE.get(state, "alpha")
        freq_range = self.BRAINWAVES[brainwave]

        return {
            "target_state": state,
            "brainwave_target": brainwave,
            "beat_frequency_range": freq_range,
            "suggested_duration": 600,  # 10 minutes
        }

    async def generate_dynamic_sound(
        self,
        user_id: str,
        params: dict,
    ) -> dict:
        """Generate dynamic sound healing audio."""
        target_state = params.get("target_state", "relaxation")
        duration = params.get("duration_seconds", 600)
        current_hrv = params.get("current_hrv")

        # Calculate optimal frequencies
        frequencies = self._calculate_frequencies(target_state, current_hrv)

        # Generate audio
        audio_data = self._generate_binaural_audio(
            base_freq=frequencies["base"],
            beat_freq=frequencies["beat"],
            duration=duration,
            sample_rate=44100,
        )

        # Convert to MP3 (simplified - in production use proper encoding)
        # For now, store as WAV
        audio_url = await self._store_dynamic_audio(user_id, audio_data)

        return {
            "audio_url": audio_url,
            "duration_seconds": duration,
            "frequencies": frequencies,
            "target_state": target_state,
            "generation_params": params,
        }

    def _calculate_frequencies(
        self,
        target_state: str,
        current_hrv: Optional[float],
    ) -> dict:
        """Calculate optimal frequencies for target state."""
        base_freq = 200  # Carrier frequency

        brainwave = self.STATE_BRAINWAVE.get(target_state, "alpha")
        freq_range = self.BRAINWAVES[brainwave]

        # Adjust based on HRV
        if current_hrv:
            if current_hrv < 30:  # Very stressed - use lower end
                beat_freq = freq_range[0]
            elif current_hrv > 60:  # Relaxed - use higher end
                beat_freq = freq_range[1]
            else:  # Middle range
                beat_freq = (freq_range[0] + freq_range[1]) / 2
        else:
            beat_freq = (freq_range[0] + freq_range[1]) / 2

        # Add solfeggio if appropriate
        solfeggio = None
        if target_state == "stress_relief":
            solfeggio = 396
        elif target_state == "healing":
            solfeggio = 528
        elif target_state == "meditation":
            solfeggio = 852

        return {
            "base": base_freq,
            "beat": round(beat_freq, 2),
            "solfeggio": solfeggio,
            "brainwave_target": brainwave,
        }

    def _generate_binaural_audio(
        self,
        base_freq: float,
        beat_freq: float,
        duration: int,
        sample_rate: int = 44100,
    ) -> bytes:
        """Generate binaural beat audio."""
        # Time array
        t = np.linspace(0, duration, duration * sample_rate, dtype=np.float32)

        # Left channel: base frequency
        left = np.sin(2 * np.pi * base_freq * t)

        # Right channel: base + beat frequency
        right = np.sin(2 * np.pi * (base_freq + beat_freq) * t)

        # Apply fade in/out (5 seconds)
        fade_samples = sample_rate * 5
        fade_in = np.linspace(0, 1, fade_samples, dtype=np.float32)
        fade_out = np.linspace(1, 0, fade_samples, dtype=np.float32)

        left[:fade_samples] *= fade_in
        left[-fade_samples:] *= fade_out
        right[:fade_samples] *= fade_in
        right[-fade_samples:] *= fade_out

        # Combine channels
        stereo = np.column_stack([left, right])

        # Normalize and convert to int16
        stereo = stereo / np.max(np.abs(stereo))
        stereo = (stereo * 32767).astype(np.int16)

        # Write to WAV buffer
        buffer = io.BytesIO()
        wavfile.write(buffer, sample_rate, stereo)
        buffer.seek(0)

        return buffer.read()

    async def _store_dynamic_audio(
        self,
        user_id: str,
        audio_data: bytes,
    ) -> str:
        """Store dynamically generated audio."""
        import uuid
        from datetime import datetime

        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        path = f"dynamic_sound/{user_id}/{timestamp}_{uuid.uuid4().hex[:8]}.wav"

        url = await self.storage.upload_audio(
            bucket="audio",
            path=path,
            data=audio_data,
            content_type="audio/wav",
        )

        return url


def get_sound_service(
    settings: Settings = Depends(get_settings),
    supabase: SupabaseService = Depends(get_supabase_service),
    storage: StorageService = Depends(get_storage_service),
) -> SoundHealingService:
    """Get sound healing service instance."""
    return SoundHealingService(settings, supabase, storage)
