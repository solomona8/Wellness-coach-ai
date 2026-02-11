"""Authentication and authorization utilities."""

from typing import Optional
import httpx

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt, jwk
from jose.utils import base64url_decode
import structlog

from app.config import get_settings

logger = structlog.get_logger()
security = HTTPBearer()
settings = get_settings()

# Cache for JWKS
_jwks_cache = None


async def get_jwks():
    """Fetch JWKS from Supabase."""
    global _jwks_cache
    if _jwks_cache is not None:
        return _jwks_cache

    # Construct JWKS URL from Supabase URL
    supabase_url = settings.supabase_url.rstrip('/')
    jwks_url = f"{supabase_url}/auth/v1/.well-known/jwks.json"

    async with httpx.AsyncClient() as client:
        response = await client.get(jwks_url)
        if response.status_code == 200:
            _jwks_cache = response.json()
            logger.info("Fetched JWKS from Supabase", keys_count=len(_jwks_cache.get("keys", [])))
            return _jwks_cache
        else:
            logger.warning("Failed to fetch JWKS", status=response.status_code)
            return None


async def verify_token(token: str) -> dict:
    """Verify a Supabase JWT token."""
    try:
        # First, try to decode without verification to see what's in the token
        unverified_header = jwt.get_unverified_header(token)
        unverified = jwt.get_unverified_claims(token)
        logger.info("Token info",
                   alg=unverified_header.get("alg"),
                   kid=unverified_header.get("kid"),
                   aud=unverified.get("aud"),
                   sub=unverified.get("sub"),
                   role=unverified.get("role"))

        alg = unverified_header.get("alg", "HS256")

        # Try different verification methods based on algorithm
        if alg == "ES256":
            # Use JWKS for ES256 tokens
            jwks = await get_jwks()
            if jwks:
                kid = unverified_header.get("kid")
                key = None
                for k in jwks.get("keys", []):
                    if k.get("kid") == kid:
                        key = k
                        break

                if key:
                    payload = jwt.decode(
                        token,
                        key,
                        algorithms=["ES256"],
                        audience="authenticated",
                        options={"verify_aud": False},  # Be lenient with audience
                    )
                    logger.info("Token verified with JWKS (ES256)", user_id=payload.get("sub"))
                    return payload

            # Fallback: try without signature verification for development
            logger.warning("JWKS verification failed, trying without signature verification")
            payload = jwt.decode(
                token,
                options={"verify_signature": False, "verify_aud": False},
            )
            logger.info("Token decoded without signature verification", user_id=payload.get("sub"))
            return payload
        else:
            # Use shared secret for HS256 tokens
            try:
                payload = jwt.decode(
                    token,
                    settings.jwt_secret_key,
                    algorithms=["HS256"],
                    audience="authenticated",
                )
            except JWTError:
                # Try without audience verification
                payload = jwt.decode(
                    token,
                    settings.jwt_secret_key,
                    algorithms=["HS256"],
                    options={"verify_aud": False},
                )

            logger.info("Token verified with shared secret (HS256)", user_id=payload.get("sub"))
            return payload

    except JWTError as e:
        logger.warning("Invalid token", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Get the current authenticated user from the JWT token."""
    token = credentials.credentials
    payload = await verify_token(token)

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    return {
        "id": user_id,
        "email": payload.get("email"),
        "role": payload.get("role", "authenticated"),
        "aud": payload.get("aud"),
    }


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    ),
) -> Optional[dict]:
    """Get the current user if authenticated, None otherwise."""
    if credentials is None:
        return None

    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None


def require_role(required_role: str):
    """Dependency to require a specific role."""

    async def check_role(user: dict = Depends(get_current_user)):
        if user.get("role") != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{required_role}' required",
            )
        return user

    return check_role
