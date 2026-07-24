from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class SensorBase(BaseModel):
    name: Optional[str] = None
    plant_type: Optional[str] = None
    location_type: Optional[str] = None
    dry_tolerance_days: Optional[int] = 3

class SensorCreate(SensorBase):
    sensor_id: str
    moisture_threshold: Optional[float] = 25.0
    sync_interval_minutes: Optional[int] = 30

class SensorUpdate(BaseModel):
    sensor_id: str
    moisture: float

class SensorRename(BaseModel):
    name: str

class SensorConfigUpdate(BaseModel):
    sensor_id: str
    moisture_threshold: Optional[float] = None
    sync_interval_minutes: Optional[int] = None

class SensorResponse(SensorBase):
    sensor_id: str
    moisture: float
    moisture_threshold: float
    sync_interval_minutes: int
    dry_since: Optional[datetime] = None
    last_update: datetime

    class Config:
        from_attributes = True