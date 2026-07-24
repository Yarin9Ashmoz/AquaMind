from typing import List, Optional
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from models.sensor import Sensor
from schemas.sensors import SensorCreate, SensorUpdate, SensorConfigUpdate

class SensorService:

    @staticmethod
    def _normalize_id(sensor_id: str) -> str:
        """Ensures consistent string identifier formatting across hardware and application layers."""
        return sensor_id.strip().replace(":", "_")

    @classmethod
    def get_all_sensors(cls, db: Session) -> List[Sensor]:
        """Retrieves all registered hardware nodes from the database."""
        return db.query(Sensor).all()

    @classmethod
    def get_sensor_by_id(cls, db: Session, sensor_id: str) -> Optional[Sensor]:
        """Fetches a single sensor entity matching the normalized identifier."""
        sensor_key = cls._normalize_id(sensor_id)
        return db.query(Sensor).filter(Sensor.sensor_id == sensor_key).first()

    @classmethod
    def create_or_update_sensor(cls, db: Session, data: SensorCreate) -> Sensor:
        """Executes an upsert operation for sensor entity onboardings and syncs latest parameters."""
        sensor_key = cls._normalize_id(data.sensor_id)
        existing_sensor = db.query(Sensor).filter(Sensor.sensor_id == sensor_key).first()

        if existing_sensor:
            if data.name:
                existing_sensor.name = data.name
            if data.plant_type:
                existing_sensor.plant_type = data.plant_type
            if data.location_type:
                existing_sensor.location_type = data.location_type
            if data.dry_tolerance_days is not None:
                existing_sensor.dry_tolerance_days = data.dry_tolerance_days
            if data.moisture_threshold is not None:
                existing_sensor.moisture_threshold = data.moisture_threshold
            if data.sync_interval_minutes is not None:
                existing_sensor.sync_interval_minutes = data.sync_interval_minutes
            
            existing_sensor.last_update = datetime.now(timezone.utc)
            db.commit()
            db.refresh(existing_sensor)
            return existing_sensor

        sensor_dict = data.dict()
        sensor_dict["sensor_id"] = sensor_key

        new_sensor = Sensor(
            **sensor_dict,
            last_update=datetime.now(timezone.utc)
        )

        db.add(new_sensor)
        db.commit()
        db.refresh(new_sensor)
        return new_sensor

    @classmethod
    def update_moisture(cls, db: Session, data: SensorUpdate) -> Optional[Sensor]:
        """Updates soil moisture metrics and refreshes operational timestamp."""
        sensor = cls.get_sensor_by_id(db, data.sensor_id)
        if not sensor:
            return None

        sensor.moisture = data.moisture
        sensor.last_update = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(sensor)
        return sensor

    @classmethod
    def update_sensor_config(cls, db: Session, config: SensorConfigUpdate) -> Optional[Sensor]:
        """Updates moisture threshold and sampling sync interval parameters received from application settings."""
        sensor = cls.get_sensor_by_id(db, config.sensor_id)
        if not sensor:
            return None

        if config.moisture_threshold is not None:
            sensor.moisture_threshold = config.moisture_threshold
        if config.sync_interval_minutes is not None:
            sensor.sync_interval_minutes = config.sync_interval_minutes

        sensor.last_update = datetime.now(timezone.utc)
        db.commit()
        db.refresh(sensor)
        return sensor

    @classmethod
    def rename_sensor(cls, db: Session, sensor_id: str, new_name: str) -> Optional[Sensor]:
        """Updates user display name for a specific sensor entity."""
        sensor = cls.get_sensor_by_id(db, sensor_id)
        if not sensor:
            return None

        sensor.name = new_name
        db.commit()
        db.refresh(sensor)
        return sensor

    @classmethod
    def delete_sensor(cls, db: Session, sensor_id: Optional[str] = None, name: Optional[str] = None) -> int:
        """Purges targeted sensor records by ID or specific display name."""
        query = db.query(Sensor)

        if sensor_id:
            sensor_key = cls._normalize_id(sensor_id)
            query = query.filter(Sensor.sensor_id == sensor_key)

        if name:
            query = query.filter(Sensor.name == name)

        deleted_count = query.delete(synchronize_session=False)
        db.commit()
        return deleted_count

    @classmethod
    def delete_all_sensors(cls, db: Session) -> int:
        """Executes full database table purge for system maintenance."""
        deleted_count = db.query(Sensor).delete()
        db.commit()
        return deleted_count