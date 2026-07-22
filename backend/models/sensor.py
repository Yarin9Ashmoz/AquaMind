from sqlalchemy import Column, Integer, String, Float, DateTime, func
from database.db import Base

class Sensor(Base):
    __tablename__ = "sensors"

    id = Column(Integer, primary_key=True, index=True)
    sensor_id = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, default="AquaMind Sensor")
    plant_type = Column(String, default="General Plant")
    location_type = Column(String, default="indoor")
    moisture = Column(Float, default=0.0)
    last_update = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    dry_tolerance_days = Column(Integer, default=3)