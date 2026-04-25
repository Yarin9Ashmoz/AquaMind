from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class SensorBase(BaseModel):
    name: str
    plant_type: str
    location_type: str = "indoor"
    dry_tolerance_days: int = Field(default=3, ge=0, le=14)

class SensorCreate(SensorBase):
    sensor_id: str
    moisture: float

class SensorUpdate(BaseModel):
    sensor_id: str
    moisture: float

class SensorRename(BaseModel):
    name: str

class SensorResponse(SensorBase):
    sensor_id: str
    moisture: float
    last_update: datetime

    class Config:
        from_attributes = True  