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

// FIX: tracks whether a phone is actively connected over BLE. The ESP32 has a
// single radio shared between WiFi and BLE. When a BLE central is connected
// (e.g. the app is mid-way through connecting/negotiating MTU/writing
// credentials), we pause outbound WiFi/HTTPS traffic so it doesn't starve the
// BLE controller of radio time. Without this, periodic checkRemoteCommand()/
// sendMeasurement() calls (which do TLS handshakes) can make requestMtu()
// on the phone hang and time out, exactly like the "Timed out after 15s"
// error from flutter_blue_plus.
volatile bool bleClientConnected = false;

// FIX: tracks whether loop() paused an in-progress WiFi STA association for
// the current BLE session, so it knows to resume it once the session ends.
bool wifiPausedForBle = false;

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
  client.setTimeout(10000);

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
  client.setTimeout(10000);

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
    // FIX: pause background WiFi/HTTPS traffic for the duration of the BLE
    // session so the radio is free for MTU negotiation / service discovery /
    // the credentials write. NOTE: this callback runs on the BLE host
    // stack's own task, not loop() — deliberately not touching WiFi here.
    // Calling WiFi.disconnect() synchronously from this task blocked long
    // enough (NVS/event-queue waits) to make the stack miss the MTU
    // exchange's timing window, which caused the very timeout this is
    // supposed to prevent. The actual WiFi pause/resume happens in loop(),
    // see wifiPausedForBle below.
    bleClientConnected = true;
  }

  void onDisconnect(BLEServer *pServer)
  {
    Serial.println("📱 Disconnected from BLE");
    bleClientConnected = false; // FIX: resume normal WiFi/HTTPS activity

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
  bleClientConnected = false; // FIX: BLE is fully torn down here, so this must be reset too
  wifiPausedForBle = false;   // about to WiFi.begin() with fresh credentials below anyway

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

  prefs.begin("sensor", true);
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("password", "");
  prefs.end();

  if (ssid != "")
  {
    savedSSID = ssid;
    savedPassword = pass;
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), pass.c_str());
    Serial.printf("📶 Found saved WiFi credentials for \"%s\" — auto-connecting in background\n", ssid.c_str());
  }
  else
  {
    Serial.println("📶 No saved WiFi credentials — skipping auto-connect");
  }

  BLEDevice::init("AquaMind Sensor");
  BLEDevice::setMTU(512);

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *service = pServer->createService(SERVICE_UUID);

  BLECharacteristic *characteristic = service->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_WRITE);

  characteristic->setCallbacks(new WriteCallback());

  service->start();
  BLEDevice::getAdvertising()->start();

  Serial.println("📡 Ready for BLE connections");
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

  // FIX: while a phone is connected over BLE, skip all WiFi/HTTPS activity
  // below so the radio stays free for the BLE session (MTU negotiation,
  // service discovery, credential write). Everything resumes automatically
  // once onDisconnect() fires.
  if (bleClientConnected)
  {
    // FIX: a WiFi STA association still in progress (e.g. the auto-reconnect
    // kicked off from setup() using saved credentials) keeps using the radio
    // even though loop() itself is paused, since that reconnect is driven by
    // the ESP-IDF WiFi task, not our loop(). That contention was starving
    // the BLE controller enough that the phone's MTU request timed out.
    // Done here (main loop task), not in the BLE callback, since calling
    // WiFi APIs directly from the BLE stack's own task blocked long enough
    // to cause the very timeout this is meant to avoid.
    if (!wifiPausedForBle && WiFi.status() != WL_CONNECTED)
    {
      WiFi.disconnect();
      wifiPausedForBle = true;
    }
    delay(100);
    return;
  }

  if (wifiPausedForBle)
  {
    // FIX: resume the WiFi connection we paused for the BLE session, unless
    // we're about to (re)connect with fresh credentials anyway.
    wifiPausedForBle = false;
    if (!startWifiSetup && savedSSID.length() > 0)
    {
      WiFi.reconnect();
    }
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    wasConnected = true;

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
