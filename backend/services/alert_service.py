from typing import Optional, Dict, Any

class AlertService:

    @classmethod
    def evaluate_sensor_data(cls, sensor_id: str, moisture: float, threshold: float = 25.0) -> Optional[Dict[str, Any]]:
        """
        Evaluates incoming moisture data against the sensor's individual threshold setting.
        """
        if moisture < threshold:
            return {
                "sensor_id": sensor_id,
                "level": "WARNING",
                "message": f"Moisture level dropped to {moisture:.1f}% (below configured threshold of {threshold:.0f}%). Immediate watering suggested.",
                "action_required": True
            }
        return None