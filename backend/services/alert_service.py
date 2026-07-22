from typing import Optional, Dict, Any

class AlertService:
    CRITICAL_MOISTURE_THRESHOLD = 30.0  # Percentage below which plant needs water

    @classmethod
    def evaluate_sensor_data(cls, sensor_id: str, moisture: float) -> Optional[Dict[str, Any]]:
        """Evaluates telemetry data against operational moisture thresholds."""
        if moisture < cls.CRITICAL_MOISTURE_THRESHOLD:
            return {
                "sensor_id": sensor_id,
                "level": "WARNING",
                "message": f"Moisture level dropped to {moisture:.1f}%. Immediate watering suggested.",
                "action_required": True
            }
        return None