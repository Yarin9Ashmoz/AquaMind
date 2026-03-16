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
#define SENSOR_PIN 32 // חובה להעביר את החוט פיזית לפין D32!

BLECharacteristic* configCharacteristic;
bool bleStopped = false;
bool startWifiSetup = false;

String savedName, savedSSID, savedPassword, savedPlantType, savedLocationType;

// פונקציה לכיבוי הבלוטות' לשמירה על זיכרון RAM
void stopBLE() {
  if (!bleStopped) {
    BLEDevice::deinit(true);
    bleStopped = true;
    Serial.println("BLE stopped to free memory for HTTPS");
  }
}

// פונקציית שליחת המדידה
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
    doc["sensor_id"] = WiFi.macAddress(); // תואם ל-Backend: sensor_id
    doc["moisture"] = (float)moisturePercent;

    String body;
    serializeJson(doc, body);
    int code = http.POST(body);
    Serial.printf("Sensor Update: %d%% (Raw: %d) | Code: %d\n", moisturePercent, rawValue, code);
    http.end();
  }
}

class WriteCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    String value = characteristic->getValue();
    StaticJsonDocument<512> doc;
    deserializeJson(doc, value);

    savedName = doc["name"].as<String>();
    savedSSID = doc["ssid"].as<String>();
    savedPassword = doc["password"].as<String>();
    savedPlantType = doc["plantType"] | "pot";
    savedLocationType = doc["locationType"] | "indoor";

    startWifiSetup = true;
  }
};

void handleWifiSetup() {
  Serial.println("Starting WiFi setup...");
  prefs.begin("sensor", false);
  prefs.putString("name", savedName);
  prefs.putString("ssid", savedSSID);
  prefs.putString("password", savedPassword);
  prefs.end();

  WiFi.disconnect(true);
  delay(500);
  WiFi.begin(savedSSID.c_str(), savedPassword.c_str());

  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 20) {
    delay(500);
    Serial.print(".");
    tries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected! Registering...");
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    if (http.begin(client, "https://aquamind-0xli.onrender.com/sensors/create")) {
      http.addHeader("Content-Type", "application/json");
      StaticJsonDocument<256> out;
      out["sensorId"] = WiFi.macAddress(); // פה ה-Create עדיין מצפה ל-sensorId לפי ה-Model שלך
      out["name"] = savedName;
      out["plantType"] = savedPlantType;
      out["locationType"] = savedLocationType;
      out["moisture"] = 0.0;
      
      String body;
      serializeJson(out, body);
      http.POST(body);
      http.end();
    }
    stopBLE();
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  WiFi.disconnect(true);
  
  prefs.begin("sensor", true);
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("password", "");
  prefs.end();

  if (ssid != "") {
    WiFi.begin(ssid.c_str(), pass.c_str());
    int wait = 0;
    while (WiFi.status() != WL_CONNECTED && wait < 15) { delay(500); wait++; }
  }

  if (WiFi.status() == WL_CONNECTED) {
    stopBLE();
  } else {
    BLEDevice::init("ESP32-Plant");
    BLEServer *server = BLEDevice::createServer();
    BLEService *service = server->createService(SERVICE_UUID);
    configCharacteristic = service->createCharacteristic(CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_WRITE);
    configCharacteristic->setCallbacks(new WriteCallback());
    service->start();
    BLEDevice::getAdvertising()->start();
    Serial.println("BLE Ready for setup");
  }
}

void loop() {
  static unsigned long lastAutoUpdate = 0;
  static unsigned long lastManualCheck = 0;

  if (startWifiSetup) {
    startWifiSetup = false;
    handleWifiSetup();
  }

  if (WiFi.status() == WL_CONNECTED) {
    // 1. בדיקת בקשה ידנית מהאפליקציה (Polling)
    if (millis() - lastManualCheck > 7000) {
      lastManualCheck = millis();
      WiFiClientSecure client;
      client.setInsecure();
      HTTPClient http;
      String url = "https://aquamind-0xli.onrender.com/sensors/" + WiFi.macAddress() + "/check-manual-request";
      if (http.begin(client, url)) {
        int code = http.GET();
        if (code == 200) {
          StaticJsonDocument<128> doc;
          deserializeJson(doc, http.getString());
          if (doc["manual_sampling_required"] == true) {
            Serial.println("Manual Sample Request!");
            sendMeasurement();
          }
        }
        http.end();
      }
    }

    // 2. עדכון אוטומטי כל 30 שניות
    if (millis() - lastAutoUpdate > 30000) {
      lastAutoUpdate = millis();
      sendMeasurement();
    }
  }
}