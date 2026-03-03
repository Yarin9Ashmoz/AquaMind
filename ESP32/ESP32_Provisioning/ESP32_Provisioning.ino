#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ArduinoJson.h>

Preferences prefs;

#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

class WriteCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    String value = characteristic->getValue();   // ⬅️ תואם ל־ESP32 3.3.7
    Serial.println("Received BLE data:");
    Serial.println(value);

    DynamicJsonDocument doc(512);
    DeserializationError err = deserializeJson(doc, value);

    if (err) {
      Serial.println("JSON parse error");
      return;
    }

    String name         = doc["name"].as<String>();
    String plantType    = doc["plantType"].as<String>();
    String locationType = doc["locationType"].as<String>();
    String ssid         = doc["ssid"].as<String>();
    String password     = doc["password"].as<String>();

    prefs.begin("sensor", false);
    prefs.putString("name", name);
    prefs.putString("plantType", plantType);
    prefs.putString("locationType", locationType);
    prefs.putString("ssid", ssid);
    prefs.putString("password", password);
    prefs.end();

    Serial.println("Saved to NVS");

    WiFi.begin(ssid.c_str(), password.c_str());
    Serial.print("Connecting to WiFi");

    int tries = 0;
    while (WiFi.status() != WL_CONNECTED && tries < 20) {
      delay(500);
      Serial.print(".");
      tries++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nWiFi connected!");

      HTTPClient http;
      http.begin("http://YOUR_BACKEND_IP:8000/sensors/create");
      http.addHeader("Content-Type", "application/json");

      DynamicJsonDocument out(256);
      out["deviceId"] = WiFi.macAddress();
      out["name"] = name;
      out["plantType"] = plantType;
      out["locationType"] = locationType;

      String body;
      serializeJson(out, body);

      int code = http.POST(body);
      Serial.printf("Backend response: %d\n", code);

      http.end();
    } else {
      Serial.println("\nWiFi failed.");
    }
  }
};

void setup() {
  Serial.begin(115200);

  BLEDevice::init("ESP32-Plant");

  BLEServer* server = BLEDevice::createServer();
  BLEService* service = server->createService(SERVICE_UUID);

  BLECharacteristic* writeChar = service->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );

  writeChar->setCallbacks(new WriteCallback());

  service->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);  // recommended
  adv->setMinPreferred(0x12);  // recommended

  BLEDevice::startAdvertising();   // ⬅️ חשוב מאוד!

  Serial.println("BLE Provisioning Ready");
}

void loop() {}
