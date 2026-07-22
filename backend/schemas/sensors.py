from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class SensorBase(BaseModel):
    name: Optional[str] = "AquaMind Sensor"
    plant_type: Optional[str] = "General Plant"
    location_type: Optional[str] = "indoor"
    dry_tolerance_days: Optional[int] = Field(default=3, ge=0, le=14)

class SensorCreate(SensorBase):
    sensor_id: str
    moisture: Optional[float] = 0.0

class SensorUpdate(BaseModel):
    sensor_id: str
    moisture: float

class SensorRename(BaseModel):
    name: str

class SensorResponse(SensorBase):
    id: Optional[int] = None
    sensor_id: str
    moisture: float
    last_update: datetime

    class Config:
        from_attributes = True