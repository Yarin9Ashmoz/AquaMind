from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database.db import SessionLocal
from models.sensor import Sensor
from datetime import datetime
from pydantic import BaseModel

class SensorCreate(BaseModel):
    sensorId: str
    name: str
    plantType: str
    locationType: str = "indoor"
    moisture: float

class SensorRename(BaseModel):
    name: str


class SensorUpdate(BaseModel):
    sensorId: str
    moisture: float

router = APIRouter(prefix="/sensors", tags=["sensors"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/debug")
def debug(db: Session = Depends(get_db)):
    sensors = db.query(Sensor).all()
    return sensors


@router.get("")
def get_sensors(db: Session = Depends(get_db)):
    sensors = db.query(Sensor).all()
    return [
        {
            "sensorId": s.sensor_id,
            "name": s.name,
            "plantType": s.plant_type,
            "locationType": s.location_type,
            "moisture": s.moisture,
            "lastUpdate": s.last_update
        }

        for s in sensors
    ]

@router.post("/create")
def create_sensor(data: SensorCreate, db: Session = Depends(get_db)):
    try:
        sensor = Sensor( 
            sensor_id=data.sensorId,
            name=data.name,
            plant_type=data.plantType,
            location_type=data.locationType,
            moisture=data.moisture, 
            last_update=datetime.utcnow(), 
        ) 
        db.add(sensor) 
        db.commit() # כאן קורית השגיאה אם הטבלה לא קיימת
        return {"status": "ok"}
    except Exception as e:
        db.rollback() # חשוב! זה משחרר את ה-Transaction ומנקה את השגיאה
        print(f"Database Error: {e}")
        return {"error": str(e)}, 500

@router.post("/{sensor_id}/rename")
def rename_sensor(sensor_id: str, data: SensorRename, db: Session = Depends(get_db)):
    sensor = db.query(Sensor).filter(Sensor.sensor_id == sensor_id).first()
    if not sensor:
        return {"error": "Sensor not found"}
    
    sensor.name = data.name
    db.commit()
    return {"status": "ok"}



@router.post("/update")
def update_sensor_data(data: SensorUpdate, db: Session = Depends(get_db)):

    sensor = db.query(Sensor).filter(Sensor.sensor_id == data.sensorId).first()
    
    if not sensor:
        return {"error": "Sensor not found in database"}, 404
    
    sensor.moisture = data.moisture
    sensor.last_update = datetime.utcnow()
    
    db.commit()
    
    print(f"✅ Success: Sensor {data.sensorId} updated to {data.moisture}%")
    return {"status": "updated", "new_moisture": sensor.moisture}