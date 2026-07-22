from typing import Dict, Any

class NotificationService:

    @staticmethod
    def send_alert_notification(alert_payload: Dict[str, Any]) -> bool:
        """Dispatches alert metrics to telemetry logs or active client push channels."""
        sensor_id = alert_payload.get("sensor_id")
        message = alert_payload.get("message")
        
        # Log event internally
        print(f"🔔 [NOTIFICATION SYSTEM] Sensor '{sensor_id}': {message}")
        
        # Here you can hook FCM / Expo push notifications for the Flutter app
        return True