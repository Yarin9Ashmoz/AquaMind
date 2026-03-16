from typing import Optional, Dict
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database.db import SessionLocal
from models.sensor import Sensor
from datetime import datetime
from pydantic import BaseModel

# מילון גלובלי (זמני) לשמירת בקשות דגימה ידנית
manual_requests: Dict[str, bool] = {}

# --- Schemas (Pydantic) ---

class SensorCreate(BaseModel):
    sensor_id: str
    name: str
    plant_type: str      # שונה ל-snake_case
    location_type: str = "indoor"
    moisture: float

class SensorRename(BaseModel):
    name: str

class SensorUpdate(BaseModel):
    sensor_id: str
    moisture: float

# --- Router Setup ---

router = APIRouter(prefix="/sensors", tags=["sensors"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Routes ---

@router.get("")
def get_sensors(db: Session = Depends(get_db)):
    sensors = db.query(Sensor).all()
    return [
        {
            "sensor_id": s.sensor_id,
            "name": s.name,
            "plant_type": s.plant_type,
            "location_type": s.location_type,
            "moisture": s.moisture,
            "last_update": s.last_update,
        }
        for s in sensors
    ]

@router.post("/create")
def create_sensor(data: SensorCreate, db: Session = Depends(get_db)):
    try:
        # בדיקה אם החיישן כבר קיים
        existing = db.query(Sensor).filter(Sensor.sensor_id == data.sensor_id).first()
        if existing:
            return {"status": "already_exists"}

        sensor = Sensor( 
            sensor_id=data.sensor_id,
            name=data.name,
            plant_type=data.plant_type,
            location_type=data.location_type,
            moisture=data.moisture, 
            last_update=datetime.utcnow(), 
        ) 
        db.add(sensor) 
        db.commit() 
        return {"status": "ok"}
    except Exception as e:
        db.rollback()
        print(f"❌ Database Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/update")
def update_sensor_data(data: SensorUpdate, db: Session = Depends(get_db)):
    # תיקון: שימוש ב-sensor_id במקום sensorId
    sensor = db.query(Sensor).filter(Sensor.sensor_id == data.sensor_id).first()
    
    if not sensor:
        raise HTTPException(status_code=404, detail=f"Sensor {data.sensor_id} not found")
    
    sensor.moisture = data.moisture
    sensor.last_update = datetime.utcnow()
    
    # ברגע שהגיע עדכון, אנחנו מבטלים את דגל הבקשה הידנית אם היה כזה
    manual_requests[data.sensor_id] = False
    
    db.commit()
    print(f"✅ Updated: Sensor {data.sensor_id} -> {data.moisture}%")
    return {"status": "updated", "new_moisture": sensor.moisture}

# --- Manual Sampling Endpoints (עבור האפליקציה וה-ESP32) ---

@router.post("/{sensor_id}/request-manual")
def request_manual_sample(sensor_id: str):
    """האפליקציה קוראת לזה כשלוחצים על Refresh"""
    manual_requests[sensor_id] = True
    return {"status": "request_sent", "sensor_id": sensor_id}

@router.get("/{sensor_id}/check-manual-request")
def check_manual_request(sensor_id: str):
    """ה-ESP32 קורא לזה כל כמה שניות ב-Loop"""
    is_required = manual_requests.get(sensor_id, False)
    return {"manual_sampling_required": is_required}

# --- Management Routes ---

@router.post("/{sensor_id}/rename")
def rename_sensor(sensor_id: str, data: SensorRename, db: Session = Depends(get_db)):
    sensor = db.query(Sensor).filter(Sensor.sensor_id == sensor_id).first()
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor not found")
    
    sensor.name = data.name
    db.commit()
    return {"status": "ok"}

@router.delete("/delete-all")
def delete_all_sensors(db: Session = Depends(get_db)):
    try:
        num_deleted = db.query(Sensor).delete()
        db.commit()
        return {"message": f"Successfully deleted {num_deleted} sensors"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/delete")
def delete_sensor(
    sensor_id: Optional[str] = Query(None, alias="sensorId"),
    name: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    if sensor_id is None and name is None:
        raise HTTPException(status_code=400, detail="Provide sensorId or name to delete")

    query = db.query(Sensor)
    if sensor_id:
        query = query.filter(Sensor.sensor_id == sensor_id)
    if name:
        query = query.filter(Sensor.name == name)

    deleted = query.delete(synchronize_session=False)
    if deleted == 0:
        raise HTTPException(status_code=404, detail="Sensor not found")

    db.commit()
    return {"deleted": deleted}