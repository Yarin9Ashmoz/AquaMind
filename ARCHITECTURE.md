# 🌿 AquaMind - Detailed System Architecture & Function Calls

AquaMind is an end-to-end IoT Smart Irrigation & Botanical AI platform. The user captures a plant image and enters parameters via the Flutter Mobile App, which communicates with a Python FastAPI Backend hosted on Render. Google Gemini AI processes the image to analyze plant health and recommend dynamic watering thresholds, which govern the ESP32 IoT node.

---

## 🏗️ High-Level Function & Call Mapping

```mermaid
graph TD
    %% Styling Definitions
    classDef mobile fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#1b5e20;
    classDef backend fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#4a148c;
    classDef ai fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#e65100;
    classDef hardware fill:#e1f5fe,stroke:#0288d1,stroke-width:2px,color:#01579b;

    %% Mobile App Components
    subgraph MobileApp ["1. Mobile App (Flutter / Dart)"]
        UI["UI Screens (HomeScreen / CameraScreen)"]:::mobile
        API_SVC["ApiService (api_service.dart)"]:::mobile
        CHAT_SVC["ChatService (chat_service.dart)"]:::mobile

        UI -->|"1a. Captures photo & moisture value"| API_SVC
        UI -->|"1b. User sends chat prompt"| CHAT_SVC
    end

    %% FastAPI Backend Components
    subgraph BackendApp ["2. Cloud Backend (Python / FastAPI on Render)"]
        FASTAPI["FastAPI App (main.py)"]:::backend

        subgraph Endpoints ["REST Endpoints"]
            EP_ANALYZE["POST /analyze"]:::backend
            EP_HISTORY["GET /history & DELETE /history/{id}"]:::backend
            EP_CHAT["POST /chat"]:::backend
        end

        subgraph Services ["Backend Services / Helpers"]
            GENAI_CALL["call_gemini_vision()"]:::backend
            HIST_STORAGE["load_history() / save_history()"]:::backend
        end

        FASTAPI --> Endpoints
        EP_ANALYZE --> GENAI_CALL
        EP_ANALYZE --> HIST_STORAGE
        EP_HISTORY --> HIST_STORAGE
    end

    %% AI Engine
    subgraph AIEngine ["3. Google Gemini AI"]
        GEMINI_MODEL["Gemini Vision API (gemini-1.5-flash)"]:::ai
    end

    %% Hardware & IoT Layer
    subgraph HardwareNode ["4. IoT Hardware (ESP32 / C++)"]
        ESP32_CODE["ESP32 Controller (main.cpp)"]:::hardware
        MOISTURE_SENSOR["Soil Moisture Sensor (Analog)"]:::hardware
        PUMP["Relay / Water Pump"]:::hardware

        MOISTURE_SENSOR -->|"Read raw analog input"| ESP32_CODE
        ESP32_CODE -->|"Trigger Pin ON/OFF"| PUMP
    end

    %% Data Connections
    API_SVC -->|"2. HTTP Multipart POST (image + moisture + plant_type)"| EP_ANALYZE
    CHAT_SVC -->|"HTTP POST (message)"| EP_CHAT
    GENAI_CALL -->|"3. generate_content(prompt, image)"| GEMINI_MODEL
    GEMINI_MODEL -->|"4. Return Diagnosis & Thresholds"| GENAI_CALL
    EP_ANALYZE -->|"5. Return JSON Analysis Response"| API_SVC

    ESP32_CODE <-->|"6. Sync Thresholds & Sync Readings (HTTP REST)"| Endpoints
```

---

## 🔄 Function-Level Execution Flow

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Flutter as Flutter App (ApiService)
    participant FastAPI as Python Backend (main.py)
    participant Storage as Storage (history.json)
    participant Gemini as Google Gemini AI API
    participant ESP32 as ESP32 Microcontroller

    %% Analyze Flow
    rect rgb(235, 247, 238)
        note over User, Gemini: Image Capture & AI Analysis Flow
        User->>Flutter: Takes plant photo & inputs moisture level
        Flutter->>FastAPI: POST /analyze (UploadFile image, float moisture, str plant_type)
        FastAPI->>Gemini: generate_content([image, prompt])
        Gemini-->>FastAPI: Returns Analysis & Recommended Thresholds
        FastAPI->>Storage: save_history(new_entry)
        FastAPI-->>Flutter: 200 OK (JSON: diagnosis, care tips, target moisture)
        Flutter-->>User: Displays Plant Diagnosis & Care Tips
    end

    %% Chat Flow
    rect rgb(243, 229, 245)
        note over User, Gemini: Chatbot Assistance Flow
        User->>Flutter: Types plant query in Chat Screen
        Flutter->>FastAPI: POST /chat (ChatRequest: message, context)
        FastAPI->>Gemini: generate_content(message)
        Gemini-->>FastAPI: Returns text answer
        FastAPI-->>Flutter: 200 OK {"reply": "..."}
        Flutter-->>User: Renders bot response in chat window
    end

    %% ESP32 Integration Flow
    rect rgb(225, 245, 254)
        note over ESP32, FastAPI: Hardware Synchronization
        ESP32->>ESP32: read_sensor_moisture()
        ESP32->>FastAPI: GET /history (Fetch latest target thresholds)
        FastAPI-->>ESP32: Returns threshold settings
        alt Moisture < Target Threshold
            ESP32->>ESP32: digitalWrite(PUMP_PIN, HIGH)
        else Moisture >= Target Threshold
            ESP32->>ESP32: digitalWrite(PUMP_PIN, LOW)
        end
    end
```

---

## 🛠️ Code Structure & Key Methods

### 1. Flutter Mobile App (`lib/services/`)

- **`api_service.dart`**:
  - `analyzePlant({File image, double moisture, String plantType})`: Sends multipart form request to `POST /analyze`.
  - `getHistory()`: Fetches past records from `GET /history`.
  - `deleteHistory(String id)`: Sends DELETE request to `DELETE /history/{id}`.
- **`chat_service.dart`**:
  - `sendMessage(String message)`: Posts user prompt to `POST /chat`.

### 2. Python Backend (`backend/main.py`)

- **`analyze_plant(image: UploadFile, moisture: float, plant_type: str)`**:
  - Decodes byte stream from image.
  - Formats AI prompt for Gemini.
  - Appends structured result into `history.json`.
- **`chat_with_bot(request: ChatRequest)`**:
  - Processes textual user Q&A via Gemini model.
- **`load_history()` / `save_history()`**:
  - Manages reading and writing local persistence data.
