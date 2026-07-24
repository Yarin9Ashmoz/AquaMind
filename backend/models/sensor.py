from sqlalchemy import Column, String, Float, Integer, DateTime
from datetime import datetime, timezone
from database import Base

class Sensor(Base):
    __tablename__ = "sensors"

    sensor_id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=True)
    plant_type = Column(String, nullable=True)
    location_type = Column(String, nullable=True)
    dry_tolerance_days = Column(Integer, nullable=True, default=3)

    # Telemetry parameters
    moisture = Column(Float, nullable=True, default=0.0)

    # Timestamp of when moisture first dropped below the threshold.
    # Reset to None once moisture recovers above threshold.
    # Used to calculate how many days a plant has been "dry".
    dry_since = Column(DateTime, nullable=True)

    # Custom configurations synchronized from application settings
    moisture_threshold = Column(Float, nullable=False, default=25.0)
    sync_interval_minutes = Column(Integer, nullable=False, default=30)

    last_update = Column(DateTime, default=lambda: datetime.now(timezone.utc))