from typing import List, Optional, Dict
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from database import get_db

from schemas.sensors import (
    SensorCreate,
    SensorUpdate,
    SensorRename,
    SensorConfigUpdate,
    SensorResponse,
)
from services.sensor_service import SensorService
from services.alert_service import AlertService

router = APIRouter(prefix="/api/v1/sensors", tags=["Sensors"])

# In-memory store for pending manual telemetry/measurement triggers for ESP devices
manual_requests: Dict[str, bool] = {}


# ---------------------------
# READ
# ---------------------------
@router.get("/", response_model=List[SensorResponse])
def get_sensors(db: Session = Depends(get_db)):
    """Retrieves all registered sensor entities."""
    return SensorService.get_all_sensors(db)


# ---------------------------
# CREATE / UPSERT
# ---------------------------
@router.post("/", response_model=SensorResponse, status_code=status.HTTP_201_CREATED)
def register_or_update_sensor(data: SensorCreate, db: Session = Depends(get_db)):
    """Registers a new sensor or syncs initial setup parameters."""
    return SensorService.create_or_update_sensor(db, data)


# ---------------------------
# TELEMETRY & ALERTS
# ---------------------------
@router.post("/telemetry", response_model=SensorResponse)
def receive_telemetry(data: SensorUpdate, db: Session = Depends(get_db)):
    """Processes incoming moisture telemetry from hardware nodes and checks alert thresholds."""
    sensor = SensorService.update_moisture(db, data)
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor node not found")

    # Clear pending manual trigger flag after successfully consuming measurement
    sensor_key = SensorService._normalize_id(data.sensor_id)
    manual_requests[sensor_key] = False

    # Evaluate alert state using custom moisture threshold
    alert = AlertService.evaluate_sensor_data(
        sensor_id=sensor.sensor_id,
        moisture=sensor.moisture,
        threshold=sensor.moisture_threshold
    )
    if alert:
        # Trigger push notification dispatch if implemented
        pass

    return sensor


# ---------------------------
# HARDWARE POLLING & COMMANDS
# ---------------------------
@router.post("/{sensor_id}/request-manual")
def request_manual_measurement(sensor_id: str):
    """Flags a pending manual measurement command for the specific hardware node."""
    sensor_key = SensorService._normalize_id(sensor_id)
    manual_requests[sensor_key] = True
    return {"status": "ok", "sensor_id": sensor_key, "manual_request_pending": True}


@router.get("/command/{sensor_id}")
def poll_hardware_command(sensor_id: str):
    """Endpoint polled by ESP hardware to inspect pending operational commands."""
    sensor_key = SensorService._normalize_id(sensor_id)
    value = manual_requests.get(sensor_key, False)

    # Consume single-shot command execution flag
    if value:
        manual_requests[sensor_key] = False

    return {"measure": value}


# ---------------------------
# CONFIGURATION & RENAME
# ---------------------------
@router.patch("/config", response_model=SensorResponse)
def update_config(config: SensorConfigUpdate, db: Session = Depends(get_db)):
    """Updates moisture threshold and sampling sync interval parameters."""
    sensor = SensorService.update_sensor_config(db, config)
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor node not found")
    return sensor


@router.post("/{sensor_id}/rename", response_model=SensorResponse)
def rename_sensor(sensor_id: str, data: SensorRename, db: Session = Depends(get_db)):
    """Updates display name for a specific sensor entity."""
    sensor = SensorService.rename_sensor(db, sensor_id, data.name)
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor node not found")
    return sensor


# ---------------------------
# DELETE
# ---------------------------
@router.delete("/all")
def delete_all_sensors(db: Session = Depends(get_db)):
    """Purges all sensor records from system database."""
    deleted = SensorService.delete_all_sensors(db)
    return {"message": f"Successfully deleted {deleted} sensors"}


@router.delete("/")
def delete_sensor(
    sensor_id: Optional[str] = Query(None, alias="sensorId"),
    name: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    """Deletes targeted sensor record by query parameters."""
    deleted = SensorService.delete_sensor(db, sensor_id=sensor_id, name=name)
    if deleted == 0:
        raise HTTPException(status_code=404, detail="Target sensor not found")
    return {"message": "Sensor successfully removed", "count": deleted}