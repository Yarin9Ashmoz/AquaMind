from sqlalchemy import Column, String, DateTime
from datetime import datetime, timezone
from database import Base

class DeviceToken(Base):
    """Stores FCM push tokens for phones that should receive AquaMind alerts."""
    __tablename__ = "device_tokens"

    token = Column(String, primary_key=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )