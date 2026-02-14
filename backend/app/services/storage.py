"""Storage service for file uploads and audio streaming."""

from typing import AsyncIterator
from datetime import datetime
import uuid

from fastapi import Depends, UploadFile
import httpx
import structlog

from app.config import Settings, get_settings

logger = structlog.get_logger()


class StorageService:
    """Service for Supabase Storage operations."""

    def __init__(self, settings: Settings):
        self.supabase_url = settings.supabase_url
        self.service_key = settings.supabase_service_role_key
        self.base_url = f"{self.supabase_url}/storage/v1"

    async def upload_meal_photo(self, user_id: str, file: UploadFile) -> str:
        """Upload a meal photo to storage."""
        # Generate unique filename
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
        filename = f"meals/{user_id}/{timestamp}_{uuid.uuid4().hex[:8]}.{ext}"

        # Read file content
        content = await file.read()

        # Upload to Supabase Storage
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/object/images/{filename}",
                headers={
                    "Authorization": f"Bearer {self.service_key}",
                    "Content-Type": file.content_type or "image/jpeg",
                },
                content=content,
            )
            response.raise_for_status()

        # Return public URL
        return f"{self.supabase_url}/storage/v1/object/public/images/{filename}"

    async def upload_audio(
        self,
        bucket: str,
        path: str,
        data: bytes,
        content_type: str = "audio/mpeg",
    ) -> str:
        """Upload audio file to storage (upserts if file already exists)."""
        async with httpx.AsyncClient() as client:
            # Use x-upsert header so re-generating a podcast overwrites
            # the previous audio file instead of returning 409 Conflict
            response = await client.post(
                f"{self.base_url}/object/{bucket}/{path}",
                headers={
                    "Authorization": f"Bearer {self.service_key}",
                    "Content-Type": content_type,
                    "x-upsert": "true",
                },
                content=data,
            )
            if response.status_code >= 400:
                logger.error(
                    "Storage upload failed",
                    status=response.status_code,
                    body=response.text,
                    bucket=bucket,
                    path=path,
                )
            response.raise_for_status()

        return f"{self.supabase_url}/storage/v1/object/public/{bucket}/{path}"

    async def get_audio_stream(self, url: str) -> AsyncIterator[bytes]:
        """Stream audio from storage URL."""
        async with httpx.AsyncClient() as client:
            async with client.stream("GET", url) as response:
                response.raise_for_status()
                async for chunk in response.aiter_bytes(chunk_size=8192):
                    yield chunk

    async def delete_file(self, bucket: str, path: str) -> bool:
        """Delete a file from storage."""
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                f"{self.base_url}/object/{bucket}/{path}",
                headers={
                    "Authorization": f"Bearer {self.service_key}",
                },
            )
            return response.status_code == 200


def get_storage_service(
    settings: Settings = Depends(get_settings),
) -> StorageService:
    """Get storage service instance."""
    return StorageService(settings)
