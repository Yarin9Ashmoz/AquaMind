from typing import List, Optional, Dict
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database.db import SessionLocal

from schemas.sensors import (
    SensorCreate,
    SensorUpdate,
    SensorRename,
    SensorResponse,
)
from services.sensor_service import SensorService

router = APIRouter(prefix="/sensors", tags=["sensors"])

# In-memory store for pending telemetry commands
manual_requests: Dict[str, bool] = {}

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ---------------------------
# GET ALL
# ---------------------------
@router.get("", response_model=List[SensorResponse])
def get_sensors(db: Session = Depends(get_db)):
    return SensorService.get_all_sensors(db)

# ---------------------------
# CREATE / UPSERT
# ---------------------------
@router.post("/create")
def create_sensor(data: SensorCreate, db: Session = Depends(get_db)):
    try:
        sensor = SensorService.create_or_update_sensor(db, data)
        return {"status": "ok", "sensor_id": sensor.sensor_id, "name": sensor.name}
    except Exception as e:
        db.rollback()
        print(f"❌ Error during sensor registration: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------
# UPDATE MOISTURE
# ---------------------------
@router.post("/update")
def update_sensor_data(data: SensorUpdate, db: Session = Depends(get_db)):
    sensor = SensorService.update_moisture(db, data)
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor target not registered")

    # Clear pending manual trigger flag after successfully consuming measurement
    sensor_key = SensorService._normalize_id(data.sensor_id)
    manual_requests[sensor_key] = False

    return {"status": "updated", "sensor_id": sensor.sensor_id, "moisture": sensor.moisture}

# ---------------------------
# REQUEST MEASURE
# ---------------------------
@router.post("/{sensor_id}/request-manual")
def request_manual(sensor_id: str):
    sensor_key = SensorService._normalize_id(sensor_id)
    manual_requests[sensor_key] = True
    return {"status": "ok"}

# ---------------------------
# ESP POLLING
# ---------------------------
@router.get("/command/{sensor_id}")
def get_command(sensor_id: str):
    sensor_key = SensorService._normalize_id(sensor_id)
    value = manual_requests.get(sensor_key, False)

    if value:
        manual_requests[sensor_key] = False
    
    return {"measure": value}

# ---------------------------
# RENAME
# ---------------------------
@router.post("/{sensor_id}/rename")
def rename_sensor(sensor_id: str, data: SensorRename, db: Session = Depends(get_db)):
    sensor = SensorService.rename_sensor(db, sensor_id, data.name)
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor target not registered")

    return {"status": "ok"}

# ---------------------------
# DELETE
# ---------------------------
@router.delete("/delete")
def delete_sensor(
    sensor_id: Optional[str] = Query(None, alias="sensorId"),
    name: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    deleted_count = SensorService.delete_sensor(db, sensor_id=sensor_id, name=name)
    if deleted_count == 0:
        raise HTTPException(status_code=404, detail="Sensor target not registered")

    return {"deleted": deleted_count}

# ---------------------------
# DELETE ALL
# ---------------------------
@router.delete("/delete-all")
def delete_all(db: Session = Depends(get_db)):
    deleted_count = SensorService.delete_all_sensors(db)
    return {"deleted": deleted_count}