#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <WiFiClientSecure.h>

Preferences prefs;

#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define SENSOR_PIN 32 // שינוי ל-32 עבור יציבות WiFi

BLECharacteristic* configCharacteristic;
bool bleStopped = false;
bool startWifiSetup = false;

String savedName, savedSSID, savedPassword, savedPlantType, savedLocationType;

void stopBLE() {
  if (!bleStopped) {
    BLEDevice::deinit(true);
    bleStopped = true;
    Serial.println("BLE stopped to free memory");
  }
}

void sendMeasurement() {
  analogRead(SENSOR_PIN);
  delay(50);
  int rawValue = analogRead(SENSOR_PIN);
  int moisturePercent = map(rawValue, 4095, 0, 0, 100);
  moisturePercent = constrain(moisturePercent, 0, 100);

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  if (http.begin(client, "https://aquamind-0xli.onrender.com/sensors/update")) {
    http.addHeader("Content-Type", "application/json");
    StaticJsonDocument<128> doc;
    
    // התאמה ל-Backend: sensor_id
    doc["sensor_id"] = WiFi.macAddress(); 
    doc["moisture"] = (float)moisturePercent;

    String body;
    serializeJson(doc, body);
    int code = http.POST(body);
    Serial.printf("Update Sent: %d%% | Code: %d\n", moisturePercent, code);
    http.end();
  }
}

// ... שאר הפונקציות (WriteCallback, startBLE, connectSavedWifi) נשארות דומות ...
// וודא שב-handleWifiSetup אתה גם משתנה ל-"sensor_id"
void handleWifiSetup() {
  // ... (התחברות ל-WiFi) ...
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    if (http.begin(client, "https://aquamind-0xli.onrender.com/sensors/create")) {
      http.addHeader("Content-Type", "application/json");
      StaticJsonDocument<256> out;
      out["sensor_id"] = WiFi.macAddress(); // שינוי ל-sensor_id
      out["name"] = savedName;
      out["plant_type"] = savedPlantType; // שינוי ל-snake_case
      out["location_type"] = savedLocationType;
      out["moisture"] = 0.0;
      
      String body;
      serializeJson(out, body);
      http.POST(body);
      http.end();
    }
    stopBLE();
  }
}

// ה-Setup וה-Loop שלך מצוינים.