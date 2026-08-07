# 🌿 AquaMind

AquaMind is an IoT soil-moisture monitoring and alerting system. An ESP32 controller reads a soil-moisture sensor and reports over WiFi to a cloud backend, which tracks each plant's condition and pushes a notification to your phone when it needs water.

It is a **monitoring and alerting** system, not automatic irrigation — there is no pump, relay, or valve involved. When moisture drops below the configured threshold, you get a notification and you do the watering.

## How it works

```
┌─────────────┐        BLE (provisioning)        ┌─────────────┐
│  Flutter    │ ────────────────────────────────▶│   ESP32     │
│  mobile app │                                   │  controller │
└─────────────┘                                   └─────────────┘
       │                                                  │
       │              HTTPS (REST API)                    │ WiFi
       ▼                                                  ▼
┌──────────────────────────────────────────────────────────────┐
│                    FastAPI backend (Render)                    │
│         PostgreSQL · Firebase Cloud Messaging · Gemini         │
└──────────────────────────────────────────────────────────────┘
```

1. **Provisioning** — the app connects to the ESP32 directly over Bluetooth to hand it WiFi credentials (never routed through the server).
2. **Telemetry** — the ESP32 reads the soil sensor every 60 seconds and reports moisture to the backend.
3. **Alerting** — the backend evaluates each reading (adjusting the threshold for outdoor sensors based on live weather) and sends a push notification via Firebase when a plant is dry.
4. **Manual measurement** — the app can request an on-demand reading; the ESP32 polls the backend for pending commands every 2 seconds and reports back.

See [ARCHITECTURE.md](ARCHITECTURE.md) for full sequence diagrams and file-level detail.

## Project structure

| Path | Description |
|---|---|
| [`frontend/`](frontend) | Flutter mobile app (Clean-ish Architecture: `presentation/`, `domain/`, `data/`) |
| [`backend/`](backend) | FastAPI service — REST API, alerting logic, push notifications |
| [`ESP32/`](ESP32) | Arduino firmware for the ESP32 sensor controller |

## Tech stack

- **Mobile app:** Flutter/Dart, Provider, `flutter_blue_plus` (BLE), `wifi_iot`, Firebase Messaging
- **Backend:** FastAPI, SQLAlchemy, PostgreSQL, Firebase Admin SDK, Google Gemini (plant identification)
- **Firmware:** Arduino (ESP32), BLE + WiFi

## Getting started

### Backend

```bash
cd backend
pip install -r requirements.txt
# configure environment variables (DB connection, API_KEY, Firebase credentials, etc.)
uvicorn main:app --reload
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

### Firmware

Open [`ESP32/ESP32_Provisioning`](ESP32/ESP32_Provisioning) in the Arduino IDE, set your target board to an ESP32, and flash it. On first boot it starts a BLE server ("AquaMind Sensor") to receive WiFi credentials from the app.

## Authentication

App-triggered endpoints that mutate state (create/update/delete/manual-trigger) require an `X-API-Key` header. Endpoints called directly by the hardware (`/telemetry`, `/command/{id}`) are intentionally left open, since the ESP32 has no practical way to hold a secret.
