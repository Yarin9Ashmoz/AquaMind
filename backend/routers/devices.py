from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas.device_token import DeviceTokenCreate
from services.device_token_service import DeviceTokenService
from security import verify_api_key

router = APIRouter(prefix="/api/v1/devices", tags=["Devices"])

@router.post("/register-token", dependencies=[Depends(verify_api_key)])
def register_token(data: DeviceTokenCreate, db: Session = Depends(get_db)):
    """Registers (or refreshes) this phone's FCM push token so the server can alert it."""
    DeviceTokenService.upsert_token(db, data.token)
    return {"status": "ok"}