from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class SensorBase(BaseModel):
    name: str
    plant_type: str
    location_type: str = "indoor"

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