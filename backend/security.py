import os
from fastapi import Header, HTTPException, status

async def verify_api_key(x_api_key: str = Header(None, alias="X-API-Key")):
    api_key_env = os.getenv("API_KEY")

    if not api_key_env:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server misconfiguration: API_KEY is not set",
        )

    if not x_api_key or x_api_key != api_key_env:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )