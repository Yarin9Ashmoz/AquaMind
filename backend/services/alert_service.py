from typing import Optional, Dict, Any
from datetime import datetime, timezone
from services.weather_service import WeatherService

class AlertService:

    @classmethod
    def evaluate_sensor_data(
        cls,
        sensor_id: str,
        moisture: float,
        threshold: float = 25.0,
        dry_since: Optional[datetime] = None,
        dry_tolerance_days: int = 3,
        location_type: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Evaluates incoming moisture data against the sensor's threshold,
        adjusting dynamically for outdoor weather conditions if applicable.
        """
        effective_threshold = threshold

        # Dynamic adjustments for outdoor plants using real-time weather
        if location_type and location_type.lower() == "outdoor":
            weather = WeatherService.get_outdoor_weather()
            if weather:
                temp = weather.get("temperature", 25.0)
                humidity = weather.get("humidity", 50.0)
                rain = weather.get("rain", 0.0)

                # If it's raining, temporarily relax the threshold requirement
                if rain > 0.0:
                    effective_threshold = max(10.0, threshold - 10.0)
                # High heat / dry humidity increases the target threshold for faster watering triggers
                elif temp > 30.0 or humidity < 35.0:
                    effective_threshold = threshold + 5.0

        if moisture >= effective_threshold:
            return None

        days_dry = 0.0
        if dry_since:
            now = datetime.now(timezone.utc)
            
            if dry_since.tzinfo is None:
                now = now.replace(tzinfo=None)
            else:
                now = now.astimezone(dry_since.tzinfo)

            days_dry = (now - dry_since).total_seconds() / 86400

        is_overdue = days_dry >= dry_tolerance_days

        if is_overdue:
            message = (
                f"Moisture at {moisture:.1f}% (below effective threshold of {effective_threshold:.0f}%) for "
                f"{days_dry:.1f} days - this exceeds the plant's {dry_tolerance_days}-day "
                f"dry tolerance. Watering needed now."
            )
        else:
            message = (
                f"Moisture level dropped to {moisture:.1f}% (below effective threshold of "
                f"{effective_threshold:.0f}%). Still within the {dry_tolerance_days}-day dry tolerance "
                f"for this plant."
            )

        return {
            "sensor_id": sensor_id,
            "level": "CRITICAL" if is_overdue else "WARNING",
            "message": message,
            "action_required": is_overdue,
        }