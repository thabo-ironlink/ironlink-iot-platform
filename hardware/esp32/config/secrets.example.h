#ifndef IRONLINK_SECRETS_H
#define IRONLINK_SECRETS_H

// ==============================================================================
// Ironlink IoT Platform
// ESP32 Sensor Node – Secrets & Environment Configuration
//
// HOW TO USE:
// 1. Copy this file:
//      cp secrets.example.h secrets.h
// 2. Edit secrets.h with real values
// 3. Flash the ESP32
//
// This file is SAFE to commit.
// Do NOT commit secrets.h (real credentials).
// ==============================================================================


// ------------------------------------------------------------------------------
// WIFI CONFIGURATION
// ------------------------------------------------------------------------------

// WiFi SSID
#define WIFI_SSID "CHANGE_ME_WIFI_SSID"

// WiFi password
#define WIFI_PASSWORD "CHANGE_ME_WIFI_PASSWORD"


// ------------------------------------------------------------------------------
// MQTT CONFIGURATION
// ------------------------------------------------------------------------------

// MQTT broker hostname or IP
// Examples:
//   "iot-gateway.local"
//   "192.168.0.50"
#define MQTT_BROKER "iot-gateway.local"

// MQTT broker port
// 1883 = no TLS (PoC)
// 8883 = TLS (production)
#define MQTT_PORT 1883

// Optional MQTT authentication
// Leave empty ("") if not required
#define MQTT_USERNAME ""
#define MQTT_PASSWORD ""


// ------------------------------------------------------------------------------
// DEVICE IDENTITY
// ------------------------------------------------------------------------------

// Logical device ID (used in topics, logs, or payloads)
// Examples:
//   "esp32-001"
//   "SITE-A-ENV-01"
#define DEVICE_ID "esp32-001"


// ------------------------------------------------------------------------------
// MQTT TOPICS
// ------------------------------------------------------------------------------

// Telemetry publish topic (PoC format)
// Example:
//   ironlink/env/HOME/esp32/dht11
#define MQTT_TELEMETRY_TOPIC "ironlink/env/HOME/esp32/dht11"

// Planned scalable format (for reference only):
//   ironlink/{tenant}/{site}/{device}/telemetry
//
// This should be updated when moving to multi-tenant deployments.


// ------------------------------------------------------------------------------
// TELEMETRY SETTINGS
// ------------------------------------------------------------------------------

// Publish interval in milliseconds
// Example:
//   5000  = every 5 seconds
//   10000 = every 10 seconds
#define PUBLISH_INTERVAL_MS 5000


// ------------------------------------------------------------------------------
// NOTES
// ------------------------------------------------------------------------------
//
// - Keep this file generic and reusable.
// - All site/client-specific values go into secrets.h.
// - Firmware logic must never depend on hard-coded credentials.
//
// ------------------------------------------------------------------------------

#endif // IRONLINK_SECRETS_H
