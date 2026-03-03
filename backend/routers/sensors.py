from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database.db import SessionLocal
from models.sensor import Sensor
from datetime import datetime

router = APIRouter(prefix="/sensors", tags=["sensors"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/")
def get_sensors(db: Session = Depends(get_db)):
    sensors = db.query(Sensor).all()
    return [
        {
            "sensorId": s.sensor_id,
            "name": s.name,
            "plantType": s.plant_type,
            "moisture": s.moisture,
            "lastUpdate": s.last_update
        }

        for s in sensors
    ]

@router.post("/create")
def create_sensor(data: dict, db: Session = Depends(get_db)):
    sensor = Sensor( 
        sensor_id=data["sensorId"],
        name=data["name"],
        plant_type=data["plantType"],
        moisture=data["moisture"], 
        last_update=datetime.utcnow(), 
        ) 
    db.add(sensor) 
    db.commit() 
    return {"status": "ok"}

@router.post("/{sensor_id}/rename")
def rename_sensor(sensor_id: str, data: dict, db: Session = Depends(get_db)):
    sensor = db.query(Sensor).filter(Sensor.sensor_id == sensor_id).first()
    if not sensor:
        return {"error": "Sensor not found"}
    
    sensor.name = data["name"]
    db.commit()
    return {"status": "ok"}

