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
bool wasConnected = false; // Tracks connection state transitions to avoid Serial spam

// Accumulates chunked BLE writes until a '\n' terminator is seen. The phone
// splits large JSON payloads into MTU-sized pieces, so a single onWrite()
// call only ever holds a fragment.
String bleRxBuffer = "";

// Restarting advertising is deferred to loop() (instead of calling it
// straight from onDisconnect(), which runs on the BLE stack's own task) so
// we can give the controller a brief settle window first. Restarting too
// quickly right after a disconnect is a common cause of follow-on
// GATT_CONN_TERMINATE_LOCAL_HOST (133) errors on the next connection.
volatile bool needsAdvertisingRestart = false;
unsigned long advertisingRestartAt = 0;

// Tracks whether a phone is actively connected over BLE. Used only to skip
// *starting new* blocking HTTP calls from loop() while a BLE session is in
// progress — it does not touch the WiFi connection itself (an earlier
// version called WiFi.disconnect()/reconnect() here, which caused more
// problems than it solved). If a call was already in-flight when the BLE
// central connected, it's left to finish on its own (bounded by its own
// short timeout — see checkRemoteCommand/sendMeasurement).
volatile bool bleClientConnected = false;

unsigned long lastUpdate = 0;
unsigned long lastCommandCheck = 0;
unsigned long lastReconnectAttempt = 0;

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
  client.setTimeout(5000);

  HTTPClient http;
  String url = "https://aquamind-0xli.onrender.com/api/v1/sensors/telemetry";

  if (http.begin(client, url))
  {
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<128> doc;
    String macAddress = WiFi.macAddress();
    macAddress.replace(":", "_");
    doc["sensor_id"] = macAddress;
    doc["moisture"] = moisturePercent;

    String body;
    serializeJson(doc, body);
    Serial.printf("📤 Sending telemetry: %s\n", body.c_str());

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
  client.setTimeout(3000);

  HTTPClient http;

  String macAddress = WiFi.macAddress();
  macAddress.replace(":", "_");

  String url = "https://aquamind-0xli.onrender.com/api/v1/sensors/command/" + macAddress;

  if (http.begin(client, url))
  {
    int code = http.GET();

    if (code == 200)
    {
      String payload = http.getString();
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
    else if (code != 404)
    {
      Serial.printf("❌ Command check HTTP Error: %d\n", code);
    }

    http.end();
  }
}

// =====================
// BLE CALLBACKS
// =====================
class MyServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    Serial.println("📱 Connected via BLE");
    bleClientConnected = true;
  }

  void onDisconnect(BLEServer *pServer)
  {
    Serial.println("📱 Disconnected from BLE");
    bleClientConnected = false;
    bleRxBuffer = ""; // discard any partial payload from the dropped session

    if (!startWifiSetup && WiFi.status() != WL_CONNECTED)
    {
      needsAdvertisingRestart = true;
      advertisingRestartAt = millis() + 1000;
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
    String chunk = pChar->getValue();
    if (chunk.length() == 0)
      return;

    // The phone falls back to ~20-byte chunks when MTU negotiation fails, so
    // the full JSON payload usually arrives across several onWrite() calls.
    // A trailing '\n' (never present inside valid JSON output) marks the end.
    bleRxBuffer += chunk;

    if (bleRxBuffer.length() > 2048)
    {
      Serial.println("⚠️ BLE RX buffer overflow — discarding");
      bleRxBuffer = "";
      return;
    }

    int newlineIdx = bleRxBuffer.indexOf('\n');
    if (newlineIdx == -1)
      return; // wait for the remaining chunks

    String message = bleRxBuffer.substring(0, newlineIdx);
    bleRxBuffer = bleRxBuffer.substring(newlineIdx + 1);

    StaticJsonDocument<512> doc;

    if (deserializeJson(doc, message))
    {
      Serial.println("❌ Failed to parse provisioning payload");
      return;
    }

    savedName = doc["name"] | "";
    savedSSID = doc["ssid"] | "";
    savedPassword = doc["password"] | "";
    savedPlantType = doc["plant_type"] | "pot";
    savedLocationType = doc["location_type"] | "indoor";
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

  if (http.begin(client, "https://aquamind-0xli.onrender.com/api/v1/sensors/"))
  {
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-API-Key", API_KEY);

    StaticJsonDocument<256> doc;

    String macAddress = WiFi.macAddress();
    macAddress.replace(":", "_");
    doc["sensor_id"] = macAddress;
    doc["name"] = savedName;
    doc["plant_type"] = savedPlantType;
    doc["location_type"] = savedLocationType;
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
  Serial.println("⚙️ Starting WiFi setup...");

  if (pServer)
    pServer->getAdvertising()->stop();

  stopBLE();
  bleClientConnected = false; // BLE is fully torn down here, so this must be reset too

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
    Serial.println("✅ WiFi Connected!");
    wasConnected = true;

    prefs.begin("sensor", false);
    prefs.putString("ssid", savedSSID);
    prefs.putString("password", savedPassword);
    prefs.end();

    registerSensor();
    sendMeasurement();
  }
  else
  {
    Serial.println("❌ Failed to connect to target WiFi SSID");
  }
}

// =====================
// SETUP
// =====================
void setup()
{
  Serial.begin(115200);
  analogReadResolution(12);

  // 1. Completely erase any previously saved WiFi credentials from NVS memory
  prefs.begin("sensor", false); // Open preferences in read-write mode (false)
  prefs.clear();                // Clears saved "ssid" and "password" entries
  prefs.end();

  // 2. Completely disable the WiFi radio to prevent background connection attempts
  WiFi.disconnect(true, true);
  WiFi.mode(WIFI_OFF);

  Serial.println("🧹 Memory cleared! Starting fresh BLE Provisioning...");

  // 3. Initialize BLE in a completely clean environment
  BLEDevice::init("AquaMind Sensor");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *service = pServer->createService(SERVICE_UUID);

  BLECharacteristic *characteristic = service->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_WRITE);

  characteristic->setCallbacks(new WriteCallback());

  service->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("📡 Ready for BLE connections");
}
// =====================
// LOOP
// =====================
void loop()
{
  if (needsAdvertisingRestart && millis() >= advertisingRestartAt)
  {
    needsAdvertisingRestart = false;
    if (pServer && !bleStopped)
      pServer->getAdvertising()->start();
  }

  if (startWifiSetup)
  {
    startWifiSetup = false;
    handleWifiSetup();
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    wasConnected = true;

    // Skip *starting new* blocking HTTP calls while a phone is connected
    // over BLE — a network hiccup right then can make one of these calls
    // block for its full timeout, starving the BLE controller of radio time
    // during MTU negotiation/service discovery. This doesn't touch the WiFi
    // connection itself, and a call already in-flight when the BLE central
    // connected is left to finish (bounded by its own short timeout below).
    if (!bleClientConnected)
    {
      // Send periodic telemetry every 60 seconds
      if (millis() - lastUpdate > 60000)
      {
        lastUpdate = millis();
        sendMeasurement();
      }

      // Check for incoming remote commands every 2 seconds
      if (millis() - lastCommandCheck > 2000)
      {
        lastCommandCheck = millis();
        checkRemoteCommand();
      }
    }
  }
  else
  {
    // Attempt reconnect quietly only if saved WiFi credentials exist
    if (savedSSID.length() > 0)
    {
      // Print notification ONCE when connection drops
      if (wasConnected)
      {
        wasConnected = false;
        Serial.println("⚠️ WiFi connection lost. Reconnecting in background...");
      }

      // Retry connecting every 10 seconds in background without flooding Serial
      if (millis() - lastReconnectAttempt > 10000)
      {
        lastReconnectAttempt = millis();
        WiFi.reconnect();
      }
    }
  }

  delay(100);
}
