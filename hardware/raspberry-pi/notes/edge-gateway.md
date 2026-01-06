# Edge Gateway – Raspberry Pi

**Ironlink IoT Platform**

## 1. Purpose of the Edge Gateway

The Raspberry Pi acts as a **local edge gateway** that bridges **field devices** (ESP32, sensors, future PLCs/VFDs) to the Ironlink platform.

It is designed to:

* Accept telemetry via **MQTT**
* Perform **lightweight ingestion & buffering**
* Persist time-series data locally
* Expose dashboards for **on-site visibility**
* Operate **without PLC/SCADA infrastructure**

This makes it ideal for:

* Small factories
* Workshops
* Welding bays
* Remote or bandwidth-constrained sites

---

## 2. Role in the Architecture

**Current PoC role**

```
ESP32 / Sensors
      ↓ MQTT
Raspberry Pi (Edge Gateway)
      ↓
Telegraf → InfluxDB → Grafana
```

**Key design choice**
The Pi is **not** doing analytics or control logic.
It is a **reliable ingestion + observability layer**.

👉 This keeps failure modes simple and predictable.

---

## 3. Hardware Profile

**Validated hardware**

* Raspberry Pi 5
* 64GB SD card
* Ethernet or stable WiFi
* No screen, keyboard, or mouse required

**Why Raspberry Pi**

* Widely available
* Low power
* Strong Docker support
* Familiar to engineers and technicians

👉 For production-heavy sites, this role can later be replaced by:

* Industrial IoT gateways
* IPCs
* PLC-integrated edge devices

---

## 4. Operating System & Base Setup

**OS**

* Raspberry Pi OS Lite (64-bit)
* No desktop environment

**Baseline configuration**

* Hostname: `iot-pi`
* SSH enabled
* User-level Docker access
* Static IP recommended (but not required for PoC)

**Why no GUI**

* Lower memory usage
* Fewer attack surfaces
* Easier remote management

---

## 5. Runtime Stack (PoC)

All runtime services are containerised and defined under:

```
infra/poc-stack/
```

### Services running on the Edge Gateway

| Service      | Purpose                    |
| ------------ | -------------------------- |
| Mosquitto    | Local MQTT broker          |
| Telegraf     | Ingestion & transformation |
| InfluxDB 1.8 | Time-series storage        |
| Grafana      | Dashboards & visualisation |

All services are orchestrated via **Docker Compose**.

👉 This mirrors how the stack will later run in cloud or VPC environments.

---

## 6. MQTT Responsibilities

The Edge Gateway:

* Accepts telemetry from devices (ESP32)
* Uses topic hierarchy for routing
* Does **not** enforce strict auth in PoC

**Observed topic pattern (PoC)**

```
ironlink/env/HOME/esp32/dht11
```

**Planned scalable pattern**

```
ironlink/{tenant}/{site}/{device}/telemetry
```

👉 This change only affects:

* ESP32 firmware
* Telegraf topic subscriptions

No infra rewrite needed.

---

## 7. Data Ingestion (Telegraf)

Telegraf subscribes to MQTT and writes to InfluxDB.

**Key characteristics**

* JSON payloads
* Automatic field extraction
* Topic-based filtering
* Lightweight enrichment possible via tags

**Validated behaviour**

* Messages confirmed via `mosquitto_pub`
* Data visible in InfluxDB
* Data surfaced in Grafana dashboards
* Device filtering works (`host = iot-pi`)

---

## 8. Observability & Operations

### What operators can see

* Device online/offline behaviour
* Environmental telemetry (temperature, humidity)
* Timestamped machine data
* Site-level dashboards

### What operators do NOT need

* SSH access
* Linux knowledge
* Direct database access

👉 Grafana becomes the **primary operational interface**.

---

## 9. Failure Modes & Expected Behaviour

| Scenario            | Expected Behaviour           |
| ------------------- | ---------------------------- |
| ESP32 offline       | No new MQTT messages         |
| MQTT broker restart | Automatic reconnection       |
| InfluxDB restart    | Short ingestion pause        |
| Pi reboot           | Stack auto-starts via Docker |
| Network outage      | Local visibility still works |

👉 This matches the **store-and-forward mindset**, even before adding disk queues.

---

## 10. Security Posture (PoC vs Production)

**PoC**

* Local network only
* No TLS
* No MQTT auth
* SSH key-based access

**Production path**

* TLS on MQTT
* Device certificates or tokens
* Network segmentation
* Central auth & audit logging

👉 Security is **progressively hardenable** without changing topology.

---

## 11. When to Use an Edge Gateway

Use this model when:

* Client has **no PLC/SCADA**
* Quick deployment is needed
* Budget is constrained
* Local dashboards add value
* Connectivity is unreliable

Do **not** use when:

* Site already has SCADA historian
* High-frequency control loops are required
* Sub-millisecond latency is needed

---

## 12. Future Extensions (Already Planned)

This gateway can evolve to support:

* PLC adapters (Modbus RTU/TCP)
* Welding machine telemetry
* VFD status monitoring
* Geo-tagging for Grafana maps
* Store-and-forward buffering
* Cloud uplink to central Ironlink platform

All without replacing the device.

---

## 13. Why This Matters for the Business Model

This edge gateway enables:

* Hardware-light SaaS onboarding
* Monthly subscription offerings
* Multi-client isolation
* Rapid PoC → production transitions
* Expansion into industrial monitoring without heavy capex

It is a **product enabler**, not just infrastructure.

---

### ✅ Status

* Implemented
* Tested
* Documented
* Ready for client PoCs


