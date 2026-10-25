/*
 * Secure IoE Remote Door Access - ESP32 Firmware
 * 
 * Hardware:
 *   - ESP32-WROOM-32 Dev Module
 *   - Servo Motor (SG90 or MG996R) connected to GPIO 18, VIN (5V), and GND
 * 
 * Required Arduino Libraries (Install via Arduino Library Manager):
 *   1. "WebSockets" by Markus Sattler (Links: WebSocketsClient.h)
 *   2. "ESP32Servo" by Kevin Harrington
 *   3. "ArduinoJson" by Benoit Blanchon (v6 or v7)
 */

#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>

// ============================================================
// CONFIGURATION (Update these with your settings)
// ============================================================
const char* WIFI_SSID     = "Uma_4G";     // 2.4 GHz Wi-Fi Name (or Mobile Hotspot)
const char* WIFI_PASSWORD = "Uma9137657256"; // Wi-Fi Password

// Cloud Render host - DO NOT INCLUDE "https://" or "wss://"
const char* WS_HOST       = "securedoor-api.onrender.com";
const int   WS_PORT       = 443;                // Port 443 for SSL / Cloud
const char* WS_PATH       = "/ws/esp32";
const bool  USE_SSL       = true;               // Set to true for Cloud Render

const char* DEVICE_ID     = "esp32_front_door_01";
const int   SERVO_PIN     = 18;                   // PWM Signal pin to Servo
const int   STATUS_LED    = 2;                    // Built-in blue LED on most ESP32 boards

// ============================================================
// GLOBALS
// ============================================================
WebSocketsClient webSocket;
Servo doorServo;

int currentAngle = 0; // 0 = Closed (Rightwards), 90 = Open (Vertical Up)
unsigned long lastHeartbeat = 0;
const unsigned long HEARTBEAT_INTERVAL = 25000; // 25 seconds
String cleanHostStr;

// ============================================================
// FORWARD DECLARATIONS
// ============================================================
void connectWiFi();
void webSocketEvent(WStype_t type, uint8_t * payload, size_t length);
void handleCommand(const String& payloadStr);
void sendRegistration();
void sendStatusUpdate(const char* requestId, const char* status, int angle, const char* doorState, const char* latchState);
void sendHeartbeat();

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n================================================");
  Serial.println("  Secure IoE Door Access - ESP32 Booting...");
  Serial.println("================================================");

  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, LOW);

  // Initialize Servo
  // Standard 50Hz PWM: 500us min (0°), 2400us max (180°)
  doorServo.setPeriodHertz(50);
  doorServo.attach(SERVO_PIN, 500, 2400);

  // Set initial position: 0 degrees (Closed / Rightwards)
  Serial.println("[SERVO] Setting initial position: 0° (CLOSED)");
  doorServo.write(0);
  currentAngle = 0;

  // Connect to Wi-Fi
  connectWiFi();

  // Sanitize host string automatically (strips https://, http://, wss://, trailing slashes)
  cleanHostStr = String(WS_HOST);
  cleanHostStr.replace("https://", "");
  cleanHostStr.replace("http://", "");
  cleanHostStr.replace("wss://", "");
  cleanHostStr.replace("ws://", "");
  while (cleanHostStr.endsWith("/")) {
    cleanHostStr.remove(cleanHostStr.length() - 1);
  }

  // Configure WebSocket Client
  Serial.printf("[WS] Configuring connection to %s:%d%s (SSL: %s)\n", 
                cleanHostStr.c_str(), WS_PORT, WS_PATH, USE_SSL ? "YES" : "NO");

  if (USE_SSL) {
    webSocket.beginSSL(cleanHostStr.c_str(), WS_PORT, WS_PATH);
  } else {
    webSocket.begin(cleanHostStr.c_str(), WS_PORT, WS_PATH);
  }

  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(3000); // Retry every 3 seconds if disconnected
  webSocket.enableHeartbeat(15000, 3000, 2);
}

// ============================================================
// MAIN LOOP
// ============================================================
void loop() {
  webSocket.loop();

  // Reconnect Wi-Fi if dropped
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  // Periodic Heartbeat
  if (millis() - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = millis();
    if (webSocket.isConnected()) {
      sendHeartbeat();
    }
  }
}

// ============================================================
// WI-FI CONNECTION
// ============================================================
void connectWiFi() {
  Serial.printf("[WIFI] Connecting to SSID: %s ", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    digitalWrite(STATUS_LED, !digitalRead(STATUS_LED)); // Toggle LED while connecting
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Connected!");
    Serial.printf("[WIFI] IP Address: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("[WIFI] Signal Strength (RSSI): %d dBm\n", WiFi.RSSI());
    digitalWrite(STATUS_LED, HIGH);

    // Synchronize NTP clock (Required for SSL/TLS certificates on Render & Cloudflare)
    Serial.print("[TIME] Synchronizing NTP time for SSL ");
    configTime(0, 0, "pool.ntp.org", "time.google.com");
    time_t now = time(nullptr);
    int retries = 0;
    while (now < 1700000000 && retries < 20) {
      delay(500);
      Serial.print(".");
      now = time(nullptr);
      retries++;
    }
    Serial.println("\n[TIME] Clock synchronized successfully!");
  } else {
    Serial.println("\n[WIFI ERROR] Failed to connect. Check SSID/Password.");
  }
}

// ============================================================
// WEBSOCKET EVENT HANDLER
// ============================================================
void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch (type) {
    case WStype_DISCONNECTED:
      Serial.println("[WS] Disconnected from server.");
      digitalWrite(STATUS_LED, LOW);
      break;

    case WStype_CONNECTED:
      Serial.printf("[WS] Connected to Server: %s\n", payload);
      digitalWrite(STATUS_LED, HIGH);
      // Immediately register device identity
      sendRegistration();
      break;

    case WStype_TEXT: {
      String msg = String((char*)payload);
      Serial.printf("[WS RECV] %s\n", msg.c_str());
      handleCommand(msg);
      break;
    }

    case WStype_BIN:
      Serial.println("[WS] Binary payload received (ignored)");
      break;

    case WStype_ERROR:
      Serial.println("[WS ERROR] Communication error encountered.");
      break;

    default:
      break;
  }
}

// ============================================================
// COMMAND PARSER & PHYSICAL ACTUATION
// ============================================================
void handleCommand(const String& payloadStr) {
  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, payloadStr);

  if (err) {
    Serial.printf("[JSON ERROR] Parse failed: %s\n", err.c_str());
    return;
  }

  const char* type = doc["type"] | "";

  // Check if this is an execution command
  if (strcmp(type, "COMMAND") == 0) {
    const char* command   = doc["command"] | "";
    const char* requestId = doc["requestId"] | "";
    int targetAngle       = doc["targetAngle"] | 0;

    Serial.println("----------------------------------------------");
    Serial.printf("⚡ COMMAND DISPATCH: %s | Target: %d° | Nonce: %s\n", command, targetAngle, requestId);
    Serial.println("----------------------------------------------");

    // Flash LED to show activity
    digitalWrite(STATUS_LED, LOW);

    if (strcmp(command, "OPEN") == 0) {
      Serial.println("[ACTUATING] Rotating Servo to 90° (Vertical Upwards - OPEN)");
      doorServo.write(90);
      currentAngle = 90;
      delay(450); // Give motor physical time to reach position

      sendStatusUpdate(requestId, "SUCCESS", 90, "open", "unlocked");
    } else if (strcmp(command, "CLOSE") == 0) {
      Serial.println("[ACTUATING] Rotating Servo to 0° (To the Right - CLOSED)");
      doorServo.write(0);
      currentAngle = 0;
      delay(450); // Give motor physical time to reach position

      sendStatusUpdate(requestId, "SUCCESS", 0, "closed", "locked");
    }

    digitalWrite(STATUS_LED, HIGH);
  }
}

// ============================================================
// OUTBOUND TELEMETRY MESSAGES
// ============================================================

// 1. Device Registration Handshake
void sendRegistration() {
  StaticJsonDocument<256> doc;
  doc["type"]      = "REGISTER";
  doc["deviceId"]  = DEVICE_ID;
  doc["ipAddress"] = WiFi.localIP().toString();
  doc["firmware"]  = "1.0.0";
  doc["angle"]     = currentAngle;

  String out;
  serializeJson(doc, out);
  webSocket.sendTXT(out);
  Serial.printf("[WS SENT] Registered as %s\n", DEVICE_ID);
}

// 2. Command Physical Status Confirmation
void sendStatusUpdate(const char* requestId, const char* status, int angle, const char* doorState, const char* latchState) {
  StaticJsonDocument<256> doc;
  doc["type"]       = "STATUS_UPDATE";
  doc["deviceId"]   = DEVICE_ID;
  doc["requestId"]  = requestId;
  doc["status"]     = status;
  doc["servoAngle"] = angle;
  doc["doorState"]  = doorState;
  doc["latchState"] = latchState;

  String out;
  serializeJson(doc, out);
  webSocket.sendTXT(out);
  Serial.printf("[WS SENT CONFIRMATION] Angle: %d° | State: %s\n", angle, latchState);
}

// 3. Keepalive Heartbeat
void sendHeartbeat() {
  StaticJsonDocument<192> doc;
  doc["type"]      = "HEARTBEAT";
  doc["deviceId"]  = DEVICE_ID;
  doc["ipAddress"] = WiFi.localIP().toString();
  doc["rssi"]      = WiFi.RSSI();
  doc["uptime"]    = millis() / 1000;

  String out;
  serializeJson(doc, out);
  webSocket.sendTXT(out);
  Serial.println("[WS SENT] Heartbeat ping");
}
