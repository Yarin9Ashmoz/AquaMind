import os
from fastapi import Header, HTTPException, status

# Shared secret between the Flutter app and this backend.
# Set API_KEY in your .env file (and hardcode the SAME value in the
# Flutter app's constants for now - fine for a single-user hobby project).
API_KEY = os.getenv("API_KEY")


async def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    """
    Lightweight guard for endpoints that mutate data or cost money (Gemini calls).
    This is NOT a login system - there's no user accounts or sessions.
    It's a single static shared secret just to stop random internet traffic
    from hitting write/delete endpoints or burning your Gemini quota.
    """
    if not API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server misconfiguration: API_KEY is not set",
        )
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )