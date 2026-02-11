"""Application configuration using Pydantic settings."""

from functools import lru_cache
from typing import Optional
import os
from dotenv import load_dotenv

from pydantic_settings import BaseSettings, SettingsConfigDict

# Load .env file explicitly before pydantic reads it
load_dotenv(override=True)


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",  # Ignore extra env vars
    )

    # Application
    app_name: str = "Wellness Monitoring API"
    app_version: str = "1.0.0"
    debug: bool = False
    environment: str = "development"

    # Supabase
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str

    # Anthropic Claude
    anthropic_api_key: Optional[str] = None
    claude_model: str = "claude-sonnet-4-20250514"

    # ElevenLabs
    elevenlabs_api_key: str
    elevenlabs_default_voice_id: str = "21m00Tcm4TlvDq8ikWAM"

    # Google Cloud
    gcp_project_id: Optional[str] = None
    gcs_bucket_name: Optional[str] = None

    # Security
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30

    # CORS
    cors_origins: list[str] = ["http://localhost:5173", "http://localhost:3000"]

    # Rate limiting
    rate_limit_requests: int = 100
    rate_limit_period: int = 60  # seconds


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    settings = Settings()
    # Log API key status at startup
    print(f"[Config] ANTHROPIC_API_KEY loaded: {'Yes' if settings.anthropic_api_key else 'No'}")
    print(f"[Config] ELEVENLABS_API_KEY loaded: {'Yes' if settings.elevenlabs_api_key else 'No'}")
    if settings.anthropic_api_key:
        print(f"[Config] ANTHROPIC key starts with: {settings.anthropic_api_key[:20]}...")
    return settings
