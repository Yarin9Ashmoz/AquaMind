from typing import Optional, Dict, Any
from datetime import datetime, timezone

class AlertService:

    @classmethod
    def evaluate_sensor_data(
        cls,
        sensor_id: str,
        moisture: float,
        threshold: float = 25.0,
        dry_since: Optional[datetime] = None,
        dry_tolerance_days: int = 3,
    ) -> Optional[Dict[str, Any]]:
        """
        Evaluates incoming moisture data against the sensor's individual threshold,
        and escalates severity based on how many days it's been dry relative to
        this plant's own dry-tolerance setting.
        """
        if moisture >= threshold:
            return None

        days_dry = 0.0
        if dry_since:
            days_dry = (datetime.now(timezone.utc) - dry_since).total_seconds() / 86400

        is_overdue = days_dry >= dry_tolerance_days

        if is_overdue:
            message = (
                f"Moisture at {moisture:.1f}% (below {threshold:.0f}% threshold) for "
                f"{days_dry:.1f} days - this exceeds the plant's {dry_tolerance_days}-day "
                f"dry tolerance. Watering needed now."
            )
        else:
            message = (
                f"Moisture level dropped to {moisture:.1f}% (below configured threshold of "
                f"{threshold:.0f}%). Still within the {dry_tolerance_days}-day dry tolerance "
                f"for this plant."
            )

        return {
            "sensor_id": sensor_id,
            "level": "CRITICAL" if is_overdue else "WARNING",
            "message": message,
            "action_required": is_overdue,
        }