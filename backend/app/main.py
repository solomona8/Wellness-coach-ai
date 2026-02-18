"""FastAPI application entry point."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import structlog

from app.config import get_settings
from app.api.v1.router import api_router

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    logger.info("Starting Wellness Monitoring API", version=settings.app_version)
    yield
    # Shutdown
    logger.info("Shutting down Wellness Monitoring API")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Wellness monitoring and coaching API with AI-powered analysis",
    lifespan=lifespan,
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "version": settings.app_version,
        "environment": settings.environment,
    }


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs" if settings.debug else "Docs disabled in production",
    }


@app.get("/privacy", response_class=HTMLResponse)
async def privacy_policy():
    """Privacy policy page."""
    return """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - Wellness Coach AI</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; color: #333; }
        h1 { color: #1a1a1a; }
        h2 { color: #2a2a2a; margin-top: 2em; }
        p, li { color: #444; }
        .updated { color: #888; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>Privacy Policy</h1>
    <p class="updated">Last updated: February 17, 2026</p>

    <p>Wellness Coach AI ("we", "our", or "the App") is committed to protecting your privacy. This policy explains how we collect, use, and safeguard your information.</p>

    <h2>Information We Collect</h2>
    <p>When you use the App, we may collect the following data:</p>
    <ul>
        <li><strong>Apple Health Data:</strong> Heart rate, heart rate variability, sleep stages, exercise sessions, and other health metrics you choose to share via HealthKit.</li>
        <li><strong>Manual Entries:</strong> Diet, mood, substance use, gratitude, meditation, and negativity exposure data you voluntarily log.</li>
        <li><strong>Account Information:</strong> Email address used for authentication.</li>
    </ul>

    <h2>How We Use Your Information</h2>
    <ul>
        <li><strong>AI-Powered Analysis:</strong> Your health data is sent to our secure backend and analyzed using AI (Anthropic Claude) to generate personalized wellness insights and daily podcast briefings.</li>
        <li><strong>Audio Generation:</strong> Podcast scripts are converted to audio using ElevenLabs text-to-speech.</li>
        <li><strong>Personalization:</strong> Data is used to detect patterns, correlations, and provide tailored recommendations.</li>
    </ul>

    <h2>Data Storage and Security</h2>
    <ul>
        <li>Your data is stored securely in Supabase (PostgreSQL) with row-level security enabled.</li>
        <li>All data transmission uses HTTPS encryption.</li>
        <li>Audio files are stored in Supabase Storage.</li>
        <li>We do not sell, rent, or share your personal health data with third parties for marketing purposes.</li>
    </ul>

    <h2>Third-Party Services</h2>
    <p>We use the following third-party services to provide our features:</p>
    <ul>
        <li><strong>Supabase:</strong> Database and authentication</li>
        <li><strong>Anthropic (Claude):</strong> AI analysis of health data</li>
        <li><strong>ElevenLabs:</strong> Text-to-speech for podcast generation</li>
        <li><strong>Render:</strong> Backend hosting</li>
    </ul>

    <h2>Your Rights</h2>
    <ul>
        <li>You can revoke HealthKit access at any time through your iPhone Settings.</li>
        <li>You can request deletion of your account and all associated data by contacting us.</li>
        <li>You can choose which health data categories to share with the App.</li>
    </ul>

    <h2>Data Retention</h2>
    <p>We retain your data for as long as your account is active. If you delete your account, all associated data will be removed from our systems.</p>

    <h2>Children's Privacy</h2>
    <p>The App is not intended for use by children under the age of 13. We do not knowingly collect personal information from children.</p>

    <h2>Changes to This Policy</h2>
    <p>We may update this privacy policy from time to time. We will notify you of any changes by updating the "Last updated" date above.</p>

    <h2>Contact Us</h2>
    <p>If you have questions about this privacy policy or your data, please contact us at the email associated with your App Store Connect developer account.</p>
</body>
</html>"""
