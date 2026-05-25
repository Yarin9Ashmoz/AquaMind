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

router = APIRouter(prefix="/sensors", tags=["sensors"])

manual_requests: Dict[str, bool] = {}

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ---------------------------
# 📡 GET ALL
# ---------------------------
@router.get("", response_model=List[SensorResponse])
def get_sensors(db: Session = Depends(get_db)):
    return db.query(Sensor).all()

# ---------------------------
# ➕ CREATE
# ---------------------------
@router.post("/create")
def create_sensor(data: SensorCreate, db: Session = Depends(get_db)):
    try:
        existing = db.query(Sensor).filter(Sensor.sensor_id == data.sensor_id).first()
        if existing:
            print(f"⚠️  Sensor {data.sensor_id} already exists")
            return {"status": "already_exists", "sensor_id": data.sensor_id}

        sensor = Sensor(
            **data.dict(),
            last_update=datetime.utcnow()
        )

        db.add(sensor)
        db.commit()
        db.refresh(sensor)
        
        print(f"✅ Sensor {data.sensor_id} created successfully")
        return {"status": "ok", "sensor_id": data.sensor_id, "name": sensor.name}

    except Exception as e:
        db.rollback()
        print(f"❌ Error creating sensor: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------
# 📤 UPDATE MOISTURE
# ---------------------------
@router.post("/update")
def update_sensor_data(data: SensorUpdate, db: Session = Depends(get_db)):

    sensor = db.query(Sensor).filter(Sensor.sensor_id == data.sensor_id).first()

    if not sensor:
        print(f"❌ Sensor {data.sensor_id} not found for update")
        raise HTTPException(status_code=404, detail="Sensor not found")

    old_moisture = sensor.moisture
    sensor.moisture = data.moisture
    sensor.last_update = datetime.utcnow()

    manual_requests[data.sensor_id] = False

    db.commit()
    
    print(f"✅ Sensor {data.sensor_id} updated: {old_moisture}% → {data.moisture}%")

    return {"status": "updated", "sensor_id": data.sensor_id, "moisture": data.moisture}

# ---------------------------
# 📲 REQUEST MEASURE (FIXED)
# ---------------------------
@router.post("/{sensor_id}/request-manual")
def request_manual(sensor_id: str):
    # המרה חזורה של underscores לקולונים (אם הם הגיעו כunderscores)
    sensor_id_with_colons = sensor_id.replace("_", ":")
    
    manual_requests[sensor_id_with_colons] = True

    print(f"📡 Manual request for {sensor_id_with_colons}")

    return {"status": "ok"}

# ---------------------------
# 🤖 ESP POLLING (FIXED + SAFE)
# ---------------------------
@router.get("/command/{sensor_id}")
def get_command(sensor_id: str):
    # המרה חזורה של underscores לקולונים (אם הם הגיעו כunderscores)
    sensor_id_with_colons = sensor_id.replace("_", ":")
    
    value = manual_requests.get(sensor_id_with_colons, False)

    # רק הדפס אם יש פקודה
    if value:
        print(f"📡 Sending measurement command to {sensor_id_with_colons}")
        manual_requests[sensor_id_with_colons] = False
    
    return {"measure": value}

# ---------------------------
# ✏️ RENAME
# ---------------------------
@router.post("/{sensor_id}/rename")
def rename_sensor(sensor_id: str, data: SensorRename, db: Session = Depends(get_db)):
    # המרה חזורה של underscores לקולונים
    sensor_id_with_colons = sensor_id.replace("_", ":")

    sensor = db.query(Sensor).filter(Sensor.sensor_id == sensor_id_with_colons).first()

    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor not found")

    sensor.name = data.name
    db.commit()

    return {"status": "ok"}

# ---------------------------
# ❌ DELETE
# ---------------------------
@router.delete("/delete")
def delete_sensor(
    sensor_id: Optional[str] = Query(None, alias="sensorId"),
    name: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    # המרה חזורה של underscores לקולונים אם צריך
    if sensor_id:
        sensor_id = sensor_id.replace("_", ":")

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

# ---------------------------
# 🧹 DELETE ALL
# ---------------------------
@router.delete("/delete-all")
def delete_all(db: Session = Depends(get_db)):

    num = db.query(Sensor).delete()
    db.commit()

    return {"deleted": num}