# ESP32 Sensor Node

**Ironlink IoT Platform**

## 1. Purpose

The ESP32 acts as a **low-cost, wireless sensor node** responsible for collecting basic machine or environmental telemetry and publishing it to the Ironlink platform via MQTT.

It is intentionally designed to:

* Work **without PLCs or SCADA**
* Be fast to deploy
* Require minimal electrical integration
* Support early PoCs and lightweight production use cases

Typical use cases:

* Environmental monitoring (temperature, humidity)
* Machine vicinity sensing
* Early-stage machine health signals
* Sites with no existing automation infrastructure

---

## 2. Supported Hardware (Validated)

### Microcontroller

* ESP32 DevKit (tested)
* USB powered

### Sensors

* DHT11 (validated)
* Digital single-wire protocol

> **Note**
> DHT11 is used for PoC due to availability and simplicity.
> For production or harsher environments, higher-accuracy sensors should be substituted.

---

## 3. Electrical & Wiring Configuration

### DHT11 → ESP32 Wiring

| DHT11 Pin | ESP32 Pin |
| --------- | --------- |
| VCC       | 3.3V      |
| GND       | GND       |
| DATA      | GPIO 26   |

**Important constraints**

* Do **not** power DHT11 from 5V
* Loose wiring causes unstable humidity readings
* Breadboard connections should be avoided for long-term installs

---

## 4. Firmware Overview

The ESP32 firmware is responsible for:

1. Connecting to WiFi
2. Connecting to an MQTT broker
3. Reading sensor data
4. Publishing telemetry as JSON
5. Repeating at a fixed interval

**Firmware location**

```
hardware/esp32/firmware/esp32_dht11_mqtt.ino
```

---

## 5. Configuration Parameters

The following parameters are environment-specific and should be adjusted per deployment.

```cpp
#define WIFI_SSID     "YOUR_WIFI"
#define WIFI_PASSWORD "YOUR_PASSWORD"

#define MQTT_BROKER   "iot-gateway.local"
#define MQTT_PORT     1883
#define MQTT_TOPIC    "ironlink/env/HOME/esp32/dht11"
```

### What changes per client

* `WIFI_SSID` / `WIFI_PASSWORD`
* `MQTT_BROKER` (edge gateway IP or hostname)
* `MQTT_TOPIC`

### Planned scalable topic format

```
ironlink/{tenant}/{site}/{device}/telemetry
```

This structure supports:

* Multi-tenant isolation
* Site-level filtering
* Device-level dashboards

---

## 6. Telemetry Payload Format

Published payload is JSON:

```json
{
  "temp_c": 25.1,
  "humidity": 48
}
```

**Design choices**

* Flat JSON structure
* Numeric values only
* No timestamps (added server-side)

This keeps firmware lightweight and flexible.

---

## 7. MQTT Behaviour

* Publish-only client
* No subscriptions required
* Automatic reconnect on broker loss
* QoS 0 (PoC default)

**Rationale**

* Low overhead
* Acceptable for non-critical telemetry
* Simplifies device logic

QoS and retained messages can be introduced later if required.

---

## 8. Power & Connectivity

### Power

* USB power via PC, Pi, or power adapter
* Stable power is critical for WiFi reliability

### Connectivity

* 2.4GHz WiFi only
* Requires outbound access to MQTT broker
* No inbound connections to device

---

## 9. Validation & Testing

### Local publish test

```bash
mosquitto_pub -h localhost \
  -t "ironlink/env/HOME/esp32/dht11" \
  -m '{"temp_c":25.1,"humidity":48}'
```

### Successful validation indicators

* Data visible in InfluxDB
* Data plotted in Grafana
* Device appears under `host = iot-pi`

---

## 10. Known Failure Modes & Diagnostics

| Symptom           | Likely Cause               |
| ----------------- | -------------------------- |
| No MQTT messages  | WiFi credentials incorrect |
| ESP32 LED off     | Power or cable issue       |
| Humidity spikes   | Loose wiring               |
| Upload timeout    | USB cable / COM port       |
| Sensor reads null | Incorrect GPIO pin         |

---

## 11. Security Posture

**PoC**

* No TLS
* No MQTT authentication
* Local network only

**Production path**

* TLS-enabled MQTT
* Device credentials
* Certificate-based auth
* Network isolation

Security enhancements do **not** require firmware redesign.

---

## 12. When to Use ESP32 Nodes

Use when:

* Client lacks PLCs or SCADA
* Fast deployment is needed
* Telemetry is low-frequency
* Budget is constrained

Avoid when:

* Safety-critical control is required
* High-frequency control loops exist
* Industrial certifications are mandatory

---

## 13. Future Extensions

Already planned:

* Support for additional sensors
* Device ID embedded in payload
* Heartbeat / last-seen telemetry
* OTA firmware updates
* Secure provisioning flow

The ESP32 remains a **sensor edge**, not a control device.

---

## 14. Relationship to the Ironlink Platform

The ESP32:

* Does not store data
* Does not make decisions
* Does not control machines

It exists to **observe and report**.

All intelligence lives upstream in:

* Edge gateways
* Central ingestion
* Analytics & alerting layers

---

### ✅ Status

* Implemented
* Tested
* Documented
* Ready for PoCs and client pilots


