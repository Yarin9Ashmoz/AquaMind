from sqlalchemy import Column, Integer, String, Float, DateTime
from datetime import datetime
from database.db import Base

class Sensor(Base):
    __tablename__ = "sensors"
    id = Column(Integer, primary_key=True, index=True)
    sensor_id = Column(String, unique=True, index=True)
    name = Column(String)
    plant_type = Column(String)
    moisture = Column(Float)
    last_update = Column(DateaTime, default=datetime.utcnow)

    