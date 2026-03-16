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
#define SENSOR_PIN 32

BLEServer* pServer = NULL;

bool startWifiSetup = false;
bool bleStopped = false;

unsigned long lastUpdate = 0;

String savedName;
String savedSSID;
String savedPassword;
String savedPlantType;
String savedLocationType;

void stopBLE() {
  if (!bleStopped) {
    BLEDevice::deinit(true);
    bleStopped = true;
    Serial.println("🔵 BLE stopped to free memory");
  }
}

void sendMeasurement() {

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ No WiFi Connection");
    return;
  }

  analogRead(SENSOR_PIN);
  delay(30);

  int rawValue = analogRead(SENSOR_PIN);

  int moisturePercent = map(rawValue, 4095, 800, 0, 100);
  moisturePercent = constrain(moisturePercent, 0, 100);

  Serial.println("\n--- 🪴 Measurement ---");
  Serial.printf("Raw: %d | Moisture: %d%%\n", rawValue, moisturePercent);

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;

  String url = "https://aquamind-0xli.onrender.com/sensors/update";

  if (http.begin(client, url)) {

    http.addHeader("Content-Type", "application/json");
    http.setTimeout(10000);

    StaticJsonDocument<128> doc;

    doc["sensor_id"] = WiFi.macAddress();
    doc["moisture"] = moisturePercent;

    String body;
    serializeJson(doc, body);

    int httpCode = http.POST(body);

    if (httpCode > 0) {
      Serial.printf("✅ Response: %d\n", httpCode);
    } else {
      Serial.printf("❌ HTTP Error: %s\n", http.errorToString(httpCode).c_str());
    }

    http.end();
  }

  Serial.println("---------------------\n");
}

class MyServerCallbacks: public BLEServerCallbacks {

  void onConnect(BLEServer* pServer) {
    Serial.println("📱 Mobile Connected");
  }

  void onDisconnect(BLEServer* pServer) {
    Serial.println("📱 Mobile Disconnected");

    if (!startWifiSetup && WiFi.status() != WL_CONNECTED) {
      pServer->getAdvertising()->start();
    }
  }
};

class WriteCallback : public BLECharacteristicCallbacks {

  void onWrite(BLECharacteristic *pChar) override {

    String value = pChar->getValue();

    if (value.length() == 0) return;

    StaticJsonDocument<512> doc;

    DeserializationError err = deserializeJson(doc, value);

    if (err) {
      Serial.println("❌ JSON parse failed");
      return;
    }

    savedName = doc["name"] | "";
    savedSSID = doc["ssid"] | "";
    savedPassword = doc["password"] | "";
    savedPlantType = doc["plant_type"] | "pot";
    savedLocationType = doc["location_type"] | "indoor";

    Serial.println("📩 Config received");

    startWifiSetup = true;
  }
};

void registerSensor() {

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;

  if (http.begin(client, "https://aquamind-0xli.onrender.com/sensors/create")) {

    http.addHeader("Content-Type", "application/json");
    http.setTimeout(10000);

    StaticJsonDocument<256> doc;

    doc["sensor_id"] = WiFi.macAddress();
    doc["name"] = savedName;
    doc["plant_type"] = savedPlantType;
    doc["location_type"] = savedLocationType;
    doc["moisture"] = 0;

    String body;
    serializeJson(doc, body);

    int code = http.POST(body);

    Serial.printf("📡 Register response: %d\n", code);

    http.end();
  }
}

void handleWifiSetup() {

  Serial.println("⚙️ Starting WiFi setup");

  if (pServer) pServer->getAdvertising()->stop();

  delay(500);

  stopBLE();

  WiFi.disconnect(true);
  delay(500);

  WiFi.mode(WIFI_STA);
  WiFi.begin(savedSSID.c_str(), savedPassword.c_str());

  Serial.print("Connecting");

  int tries = 0;

  while (WiFi.status() != WL_CONNECTED && tries < 20) {
    delay(1000);
    Serial.print(".");
    tries++;
  }

  if (WiFi.status() == WL_CONNECTED) {

    Serial.println("\n✨ WiFi Connected");
    Serial.println(WiFi.localIP());

    prefs.begin("sensor", false);
    prefs.putString("ssid", savedSSID);
    prefs.putString("password", savedPassword);
    prefs.end();

    registerSensor();

    sendMeasurement();
  }
  else {

    Serial.println("\n❌ WiFi Failed");

    delay(3000);
    ESP.restart();
  }
}

void setup() {

  Serial.begin(115200);

  delay(1000);

  Serial.println("🚀 AquaMind Booting");

  analogReadResolution(12);

  prefs.begin("sensor", true);
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("password", "");
  prefs.end();

  if (ssid != "" && ssid != "null") {

    Serial.print("🔄 Reconnecting to ");
    Serial.println(ssid);

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), pass.c_str());
  }

  BLEDevice::init("AquaMind Sensor");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  BLECharacteristic *pChar = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );

  pChar->setCallbacks(new WriteCallback());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();

  Serial.println("📡 BLE Ready");
}

void loop() {

  if (startWifiSetup) {

    startWifiSetup = false;

    handleWifiSetup();
  }

  if (WiFi.status() == WL_CONNECTED) {

    if (millis() - lastUpdate > 15000) {

      lastUpdate = millis();

      sendMeasurement();
    }
  }
  else {

    static unsigned long lastRetry = 0;

    if (millis() - lastRetry > 30000) {

      lastRetry = millis();

      Serial.println("⚠️ WiFi lost - reconnecting");

      WiFi.reconnect();
    }
  }
}