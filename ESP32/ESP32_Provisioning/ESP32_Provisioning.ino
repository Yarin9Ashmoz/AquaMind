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

// Must match the API_KEY value in backend/.env exactly.
#define API_KEY "my7Super9Secret2Key_dont_share"

BLEServer *pServer = NULL;

bool startWifiSetup = false;
bool bleStopped = false;

unsigned long lastUpdate = 0;
unsigned long lastCommandCheck = 0;

String savedName;
String savedSSID;
String savedPassword;
String savedPlantType;
String savedLocationType;
int savedDryToleranceDays = 3;

// =====================
// BLE STOP
// =====================
void stopBLE()
{
  if (!bleStopped)
  {
    BLEDevice::deinit(true);
    bleStopped = true;
    Serial.println("🔵 BLE stopped");
  }
}

// =====================
// SEND MEASUREMENT
// =====================
void sendMeasurement()
{

  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("❌ WiFi not connected, skipping measurement");
    return;
  }

  int sum = 0;
  for (int i = 0; i < 5; i++)
  {
    sum += analogRead(SENSOR_PIN);
    delay(50);
  }
  int rawValue = sum / 5;

  int moisturePercent = map(rawValue, 4095, 800, 0, 100);
  moisturePercent = constrain(moisturePercent, 0, 100);

  Serial.printf("🌱 Raw: %d | Moisture: %d%%\n", rawValue, moisturePercent);

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);

  HTTPClient http;

  // FIXED: correct route under the /api/v1 prefix
  String url = "https://aquamind-0xli.onrender.com/api/v1/sensors/telemetry";

  if (http.begin(client, url))
  {
    http.addHeader("Content-Type", "application/json");
    // NOTE: telemetry endpoint is intentionally left open (no API key) on the backend,
    // since it's called directly by hardware like this.

    StaticJsonDocument<128> doc;
    String macAddress = WiFi.macAddress();
    macAddress.replace(":", "_");
    doc["sensor_id"] = macAddress;
    doc["moisture"] = moisturePercent;

    String body;
    serializeJson(doc, body);
    Serial.printf("📤 Sending: %s\n", body.c_str());

    int httpCode = http.POST(body);

    if (httpCode == 200)
    {
      Serial.println("✅ Measurement sent successfully");
    }
    else
    {
      Serial.printf("❌ HTTP Error: %d | Response: %s\n", httpCode, http.getString().c_str());
    }

    http.end();
  }
  else
  {
    Serial.println("❌ Failed to connect to server");
  }
}

// =====================
// CHECK SERVER COMMAND
// =====================
void checkRemoteCommand()
{

  if (WiFi.status() != WL_CONNECTED)
  {
    return;
  }

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);

  HTTPClient http;

  String macAddress = WiFi.macAddress();
  macAddress.replace(":", "_");

  // FIXED: correct route under the /api/v1 prefix
  String url = "https://aquamind-0xli.onrender.com/api/v1/sensors/command/";
  url += macAddress;

  if (http.begin(client, url))
  {
    int code = http.GET();

    if (code == 200)
    {
      String payload = http.getString();
      Serial.printf("📥 Server response: %s\n", payload.c_str());

      StaticJsonDocument<128> doc;
      DeserializationError error = deserializeJson(doc, payload);

      if (error)
      {
        Serial.printf("❌ JSON parse error: %s\n", error.c_str());
      }
      else
      {
        bool measure = doc["measure"].as<bool>();

        if (measure)
        {
          Serial.println("📡 Remote measurement triggered!");
          sendMeasurement();
        }
      }
    }
    else
    {
      Serial.printf("❌ Server HTTP Error: %d\n", code);
    }

    http.end();
  }
  else
  {
    Serial.println("❌ Failed to connect to server for command check");
  }
}

// =====================
// BLE CALLBACKS
// =====================
class MyServerCallbacks : public BLEServerCallbacks
{

  void onConnect(BLEServer *pServer)
  {
    Serial.println("📱 Connected");
  }

  void onDisconnect(BLEServer *pServer)
  {
    Serial.println("📱 Disconnected");

    if (!startWifiSetup && WiFi.status() != WL_CONNECTED)
    {
      pServer->getAdvertising()->start();
    }
  }
};

// =====================
// WIFI CONFIG VIA BLE
// =====================
class WriteCallback : public BLECharacteristicCallbacks
{

  void onWrite(BLECharacteristic *pChar) override
  {
    String value = pChar->getValue();
    if (value.length() == 0)
      return;

    StaticJsonDocument<512> doc;

    if (deserializeJson(doc, value))
      return;

    savedName = doc["name"] | "";
    savedSSID = doc["ssid"] | "";
    savedPassword = doc["password"] | "";
    savedPlantType = doc["plant_type"] | "pot";
    savedLocationType = doc["location_type"] | "indoor";
    // FIXED: this was never being read before, so the app's dry-tolerance
    // selection (or the AI-suggested value) was silently dropped.
    savedDryToleranceDays = doc["dry_tolerance_days"] | 3;

    startWifiSetup = true;
  }
};

// =====================
// REGISTER SENSOR
// =====================
void registerSensor()
{

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);

  HTTPClient http;

  // FIXED: correct route under the /api/v1 prefix
  if (http.begin(client, "https://aquamind-0xli.onrender.com/api/v1/sensors/"))
  {
    http.addHeader("Content-Type", "application/json");
    // FIXED: this endpoint is now protected - must send the shared API key.
    http.addHeader("X-API-Key", API_KEY);

    StaticJsonDocument<256> doc;

    String macAddress = WiFi.macAddress();
    macAddress.replace(":", "_");
    doc["sensor_id"] = macAddress;
    doc["name"] = savedName;
    doc["plant_type"] = savedPlantType;
    doc["location_type"] = savedLocationType;
    // FIXED: now actually forwarding the value the user/AI chose in the app.
    doc["dry_tolerance_days"] = savedDryToleranceDays;

    String body;
    serializeJson(doc, body);
    Serial.printf("📝 Registering sensor: %s\n", body.c_str());

    int httpCode = http.POST(body);

    if (httpCode == 200 || httpCode == 201)
    {
      Serial.println("✅ Sensor registered successfully");
    }
    else
    {
      Serial.printf("❌ Registration failed: %d | %s\n", httpCode, http.getString().c_str());
    }

    http.end();
  }
  else
  {
    Serial.println("❌ Failed to connect to server for registration");
  }
}

// =====================
// WIFI SETUP
// =====================
void handleWifiSetup()
{

  Serial.println("⚙️ WiFi setup");

  if (pServer)
    pServer->getAdvertising()->stop();

  stopBLE();

  WiFi.disconnect(true);
  delay(500);

  WiFi.begin(savedSSID.c_str(), savedPassword.c_str());

  int tries = 0;

  while (WiFi.status() != WL_CONNECTED && tries < 20)
  {
    delay(1000);
    tries++;
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    Serial.println("✅ WiFi Connected");

    prefs.begin("sensor", false);
    prefs.putString("ssid", savedSSID);
    prefs.putString("password", savedPassword);
    prefs.end();

    registerSensor();
    sendMeasurement();
  }
}

// =====================
// SETUP
// =====================
void setup()
{

  Serial.begin(115200);
  analogReadResolution(12);

  prefs.begin("sensor", true);

  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("password", "");

  prefs.end();

  if (ssid != "")
  {
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), pass.c_str());
  }

  BLEDevice::init("AquaMind Sensor");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *service = pServer->createService(SERVICE_UUID);

  BLECharacteristic *characteristic = service->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_WRITE);

  characteristic->setCallbacks(new WriteCallback());

  service->start();
  BLEDevice::getAdvertising()->start();

  Serial.println("📡 Ready");
}

// =====================
// LOOP
// =====================
void loop()
{

  if (startWifiSetup)
  {
    startWifiSetup = false;
    handleWifiSetup();
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    if (millis() - lastUpdate > 60000)
    {
      lastUpdate = millis();
      Serial.println("\n📡 Sending periodic measurement...");
      sendMeasurement();
    }

    if (millis() - lastCommandCheck > 2000)
    {
      lastCommandCheck = millis();
      Serial.println("\n🔍 Checking for remote commands...");
      checkRemoteCommand();
    }
  }
  else
  {
    delay(1000);
    WiFi.reconnect();
    Serial.println("⚠️  WiFi disconnected, retrying...");
  }

  delay(100);
}