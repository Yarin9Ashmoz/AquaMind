import os
import json
import base64
from typing import Dict, Any, List

import firebase_admin
from firebase_admin import credentials, messaging

_firebase_app = None


def _init_firebase():
    """Lazily initializes the Firebase Admin SDK from the base64-encoded service account."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    creds_b64 = os.getenv("FIREBASE_CREDENTIALS_BASE64")
    if not creds_b64:
        print("⚠️ FIREBASE_CREDENTIALS_BASE64 not set - push notifications are disabled")
        return None

    try:
        creds_json = json.loads(base64.b64decode(creds_b64).decode("utf-8"))
        cred = credentials.Certificate(creds_json)
        _firebase_app = firebase_admin.initialize_app(cred)
        print("✅ Firebase Admin SDK initialized")
        return _firebase_app
    except Exception as e:
        print(f"❌ Failed to initialize Firebase Admin SDK: {e}")
        return None


class NotificationService:

    @staticmethod
    def send_alert_notification(alert_payload: Dict[str, Any], tokens: List[str]) -> bool:
        """Logs the alert internally, and pushes a real FCM notification to every
        registered phone token."""
        sensor_id = alert_payload.get("sensor_id")
        message_text = alert_payload.get("message")

        print(f"🔔 [NOTIFICATION SYSTEM] Sensor '{sensor_id}': {message_text}")

        app = _init_firebase()
        if not app or not tokens:
            return False

        success_count = 0
        for token in tokens:
            try:
                msg = messaging.Message(
                    notification=messaging.Notification(
                        title="AquaMind Alert 🌱",
                        body=message_text,
                    ),
                    token=token,
                )
                messaging.send(msg)
                success_count += 1
            except Exception as e:
                print(f"❌ Failed to send push to a registered device: {e}")

        return success_count > 0