from typing import List
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from models.device_token import DeviceToken

class DeviceTokenService:

    @staticmethod
    def upsert_token(db: Session, token: str) -> DeviceToken:
        """Registers a new push token, or just refreshes its timestamp if already known."""
        existing = db.query(DeviceToken).filter(DeviceToken.token == token).first()
        if existing:
            existing.updated_at = datetime.now(timezone.utc)
            db.commit()
            db.refresh(existing)
            return existing

        new_token = DeviceToken(token=token)
        db.add(new_token)
        db.commit()
        db.refresh(new_token)
        return new_token

    @staticmethod
    def get_all_tokens(db: Session) -> List[str]:
        return [t.token for t in db.query(DeviceToken).all()]