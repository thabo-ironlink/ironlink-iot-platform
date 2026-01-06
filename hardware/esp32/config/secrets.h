#ifndef IRONLINK_SECRETS_H
#define IRONLINK_SECRETS_H

// ==============================================================================
// Ironlink IoT Platform
// ESP32 Sensor Node – Runtime Secrets (LOCAL ONLY)
//
// ⚠️ DO NOT COMMIT THIS FILE ⚠️
// This file contains real credentials and site-specific configuration.
// It must be listed in .gitignore.
//
// This file is loaded by the ESP32 firmware at compile time.
// ==============================================================================


// ------------------------------------------------------------------------------
// WIFI CONFIGURATION (CHANGE PER SITE)
// ------------------------------------------------------------------------------

// WiFi SSID at the deployment site
#define WIFI_SSID "SITE_WIFI_NAME"

// WiFi password
#define WIFI_PASSWORD "SITE_WIFI_PASSWORD"


// ------------------------------------------------------------------------------
// MQTT CONFIGURATION (CHANGE PER GATEWAY / ENVIRONMENT)
// ------------------------------------------------------------------------------

// MQTT broker hostname or IP address
// Examples:
//   "iot-gateway.local"
//   "192.168.0.50"
#define MQTT_BROKER "192.168.0.50"

// MQTT broker port
// 1883 = no TLS (PoC / local LAN)
// 8883 = TLS (production)
#define MQTT_PORT 1883

// Optional MQTT authentication
// Leave empty ("") if broker does not require auth
#define MQTT_USERNAME ""
#define MQTT_PASSWORD ""


// ------------------------------------------------------------------------------
// DEVICE IDENTITY (CHANGE PER ESP32)
// ------------------------------------------------------------------------------

// Unique logical identifier for this ESP32
// Use a label that matches dashboards and provisioning records
// Examples:
//   "esp32-001"
//   "SITE-A-ENV-01"
#define DEVICE_ID "SITE-A-ENV-01"


// ------------------------------------------------------------------------------
// MQTT TOPICS (CHANGE PER SITE / DEVICE)
// ------------------------------------------------------------------------------

// Telemetry publish topic
// Current PoC format:
#define MQTT_TELEMETRY_TOPIC "ironlink/env/HOME/esp32/dht11"

// Planned scalable format (future):
// ironlink/{tenant}/{site}/{device}/telemetry
// Example:
// ironlink/clientA/siteA/SITE-A-ENV-01/telemetry


// ------------------------------------------------------------------------------
// TELEMETRY SETTINGS
// ------------------------------------------------------------------------------

// Publish interval in milliseconds
// 5000  = every 5 seconds
// 10000 = every 10 seconds
#define PUBLISH_INTERVAL_MS 5000


// ------------------------------------------------------------------------------
// NOTES
// ------------------------------------------------------------------------------
//
// - Each ESP32 MUST have a unique DEVICE_ID.
// - Do not reuse topics across physical devices.
// - Keep credentials out of firmware (.ino) files.
// - For production, this file will also include TLS certs.
//
// ------------------------------------------------------------------------------

#endif // IRONLINK_SECRETS_H
