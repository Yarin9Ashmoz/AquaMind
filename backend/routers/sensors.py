from typing import List, Optional, Dict
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database.db import SessionLocal
from models.sensor import Sensor
from datetime import datetime

from schemas.sensors import (
    SensorCreate,
    SensorUpdate,
    SensorRename,
    SensorResponse,
)


manual_requests: Dict[str, bool] = {}

router = APIRouter(prefix="/sensors", tags=["sensors"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Routes ---

@router.get("", response_model=List[SensorResponse])
def get_sensors(db: Session = Depends(get_db)):
    return db.query(Sensor).all()

@router.post("/create")
def create_sensor(data: SensorCreate, db: Session = Depends(get_db)):
    try:
        existing = db.query(Sensor).filter(Sensor.sensor_id == data.sensor_id).first()
        if existing:
            return {"status": "already_exists"}

        sensor = Sensor(
            **data.dict(), 
            last_update=datetime.utcnow()
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
    sensor = db.query(Sensor).filter(Sensor.sensor_id == data.sensor_id).first()
    
    if not sensor:
        raise HTTPException(status_code=404, detail=f"Sensor {data.sensor_id} not found")
    
    sensor.moisture = data.moisture
    sensor.last_update = datetime.utcnow()
    
    manual_requests[data.sensor_id] = False
    
    db.commit()
    print(f"✅ Updated: Sensor {data.sensor_id} -> {data.moisture}%")
    return {"status": "updated", "new_moisture": sensor.moisture}

# --- Manual Sampling Endpoints ---

@router.post("/{sensor_id}/request-manual")
def request_manual_sample(sensor_id: str):
    manual_requests[sensor_id] = True
    return {"status": "request_sent", "sensor_id": sensor_id}

@router.get("/{sensor_id}/check-manual-request")
def check_manual_request(sensor_id: str):
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

@router.delete("/delete-all")
def delete_all_sensors(db: Session = Depends(get_db)):
    try:
        num_deleted = db.query(Sensor).delete()
        db.commit()
        return {"message": f"Successfully deleted {num_deleted} sensors"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))