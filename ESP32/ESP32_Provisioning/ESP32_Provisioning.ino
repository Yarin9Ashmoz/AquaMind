#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ArduinoJson.h>

Preferences prefs;

#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define SENSOR_PIN 34 // Analog pin for the moisture sensor

class WriteCallback : public BLECharacteristicCallbacks
{
  void onWrite(BLECharacteristic *characteristic) override
  {
    String value = characteristic->getValue();
    Serial.println("Received BLE data:");
    Serial.println(value);

    DynamicJsonDocument doc(512);
    DeserializationError err = deserializeJson(doc, value);

    if (err)
    {
      Serial.println("JSON parse error");
      return;
    }

    // Extracting provisioning data from BLE JSON
    String name = doc["name"].as<String>();
    String plantType = doc["plantType"].as<String>();
    String locationType = doc["locationType"].as<String>();
    String ssid = doc["ssid"].as<String>();
    String password = doc["password"].as<String>();

    // Saving credentials and settings to Non-Volatile Storage (NVS)
    prefs.begin("sensor", false);
    prefs.putString("name", name);
    prefs.putString("plantType", plantType);
    prefs.putString("locationType", locationType);
    prefs.putString("ssid", ssid);
    prefs.putString("password", password);
    prefs.end();

    Serial.println("Saved to NVS. Connecting to WiFi...");

    // Initializing WiFi connection with received credentials
    WiFi.begin(ssid.c_str(), password.c_str());
    int tries = 0;
    while (WiFi.status() != WL_CONNECTED && tries < 20)
    {
      delay(500);
      Serial.print(".");
      tries++;
    }

    if (WiFi.status() == WL_CONNECTED)
    {
      Serial.println("\nWiFi connected! Registering sensor...");

      HTTPClient http;
      // Using HTTPS and the 'create' endpoint on Render
      http.begin("https://aquamind-0xli.onrender.com/sensors/create");
      http.addHeader("Content-Type", "application/json");

      // Creating the registration JSON payload (matches Backend Pydantic model)
      DynamicJsonDocument out(256);
      out["sensorId"] = WiFi.macAddress();
      out["name"] = name;
      out["plantType"] = plantType;
      out["locationType"] = locationType;
      out["moisture"] = 0.0; // Initial moisture value

      String body;
      serializeJson(out, body);

      int code = http.POST(body);
      Serial.printf("Register response code: %d\n", code);
      http.end();
    }
  }
};

void setup()
{
  Serial.begin(115200);

  // Load existing credentials from memory to allow auto-reconnect on boot
  prefs.begin("sensor", true);
  String savedSsid = prefs.getString("ssid", "");
  String savedPass = prefs.getString("password", "");
  prefs.end();

  if (savedSsid != "")
  {
    WiFi.begin(savedSsid.c_str(), savedPass.c_str());
    Serial.println("Attempting to connect to saved WiFi...");
  }

  // Initialize BLE Service and Characteristic
  BLEDevice::init("ESP32-Plant");
  BLEServer *server = BLEDevice::createServer();
  BLEService *service = server->createService(SERVICE_UUID);
  BLECharacteristic *writeChar = service->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_WRITE);

  writeChar->setCallbacks(new WriteCallback());
  service->start();

  // Start BLE Advertising so the phone app can find the device
  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("System Ready. BLE Advertising...");
}

void loop()
{
  static unsigned long lastUpdate = 0;

  // Periodic update: send measurement every 30 seconds if WiFi is connected
  if (WiFi.status() == WL_CONNECTED && (millis() - lastUpdate > 30000))
  {
    lastUpdate = millis();

    int rawValue = analogRead(SENSOR_PIN);
    // Convert analog raw data (0-4095) to percentage (0-100)
    // Adjust 4095 (dry) and 0 (wet) based on your specific sensor calibration
    float moisturePercent = map(rawValue, 4095, 0, 0, 100);

    HTTPClient http;
    // Update endpoint to refresh current moisture in the Database
    http.begin("https://aquamind-0xli.onrender.com/sensors/update");
    http.addHeader("Content-Type", "application/json");

    // Creating update JSON payload
    DynamicJsonDocument doc(128);
    doc["sensorId"] = WiFi.macAddress();
    doc["moisture"] = moisturePercent;

    String body;
    serializeJson(doc, body);

    int code = http.POST(body);
    Serial.printf("Update moisture (%.2f%%) response code: %d\n", moisturePercent, code);

    http.end();
  }
}