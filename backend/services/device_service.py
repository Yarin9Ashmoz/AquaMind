from typing import Dict, Any
from datetime import datetime, timezone

class DeviceService:

    @staticmethod
    def get_device_health(sensor_id: str, last_update: datetime) -> Dict[str, Any]:
        """Calculates operational status and latency for microcontrollers."""
        if not last_update:
            return {"status": "UNKNOWN", "is_online": False}

        # Calculate offset in seconds
        now = datetime.now(timezone.utc)
        time_diff = (now - last_update).total_seconds()

        # If updated within the last 10 minutes, treat as online
        is_online = time_diff < 600

        return {
            "sensor_id": sensor_id,
            "is_online": is_online,
            "status": "ONLINE" if is_online else "OFFLINE",
            "seconds_since_last_beat": int(time_diff)
        }