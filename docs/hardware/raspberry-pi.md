# Raspberry Pi – Edge Gateway

**Ironlink IoT Platform**

## 1. Purpose

The Raspberry Pi is used as an **edge gateway** in the Ironlink IoT Platform.
It provides a lightweight, on-site runtime for ingesting telemetry from field devices (e.g. ESP32, future PLCs), storing time-series data locally, and exposing operational dashboards.

This approach is optimized for:

* Sites with **no PLC or SCADA**
* Rapid PoC and pilot deployments
* Low to moderate telemetry volumes
* Unreliable or constrained connectivity

---

## 2. Role in the Platform

At a site level, the Raspberry Pi performs the following functions:

* Runs a **local MQTT broker**
* Ingests telemetry using **Telegraf**
* Stores time-series data in **InfluxDB**
* Serves **Grafana dashboards** locally
* Acts as a bridge to future cloud ingestion

It does **not**:

* Control machines
* Perform analytics
* Replace PLCs or historians

---

## 3. Validated Hardware

### Tested Configuration

* Raspberry Pi 5
* 64GB SD card
* Ethernet or stable WiFi
* USB power supply
* Headless (no monitor/keyboard)

### Why Raspberry Pi

* Low cost
* Low power
* Strong Docker ecosystem
* Easy replacement and scaling

For heavier industrial use, this role can later migrate to:

* Industrial gateways
* IPCs
* PLC-adjacent edge devices

---

## 4. Operating System

**OS**

* Raspberry Pi OS Lite (64-bit)

**Baseline configuration**

* Hostname: `iot-pi`
* SSH enabled
* No desktop environment
* Docker + Docker Compose installed

**Why headless**

* Reduced resource usage
* Fewer failure points
* Easier remote administration

---

## 5. Runtime Stack

All services are containerized and defined under:

```
infra/poc-stack/
```

### Services

| Service      | Purpose                    |
| ------------ | -------------------------- |
| Mosquitto    | Local MQTT broker          |
| Telegraf     | Telemetry ingestion        |
| InfluxDB 1.8 | Time-series storage        |
| Grafana      | Dashboards & visualisation |

Services are started via:

```bash
docker compose up -d
```

---

## 6. MQTT Configuration

### Role

* Accepts telemetry from ESP32 and future devices
* Uses topic hierarchy for routing
* Local-only in PoC mode

### Observed PoC topics

```
ironlink/env/HOME/esp32/dht11
```

### Planned scalable format

```
ironlink/{tenant}/{site}/{device}/telemetry
```

This enables:

* Multi-tenant support
* Site filtering
* Device isolation in dashboards

---

## 7. Data Ingestion (Telegraf)

Telegraf subscribes to MQTT topics and writes data into InfluxDB.

**Characteristics**

* JSON payload ingestion
* Automatic field extraction
* Topic-based filtering
* Tagging possible for site, device, geography

**Validated behaviour**

* Data visible via Influx queries
* Device filtering works in Grafana
* Stable ingestion during broker restarts

---

## 8. Local Observability (Grafana)

Grafana is exposed locally and provides:

* Device dashboards
* Time-series visualisation
* Operational health checks

Grafana acts as the **primary interface** for:

* Operators
* Technicians
* Site supervisors

No direct database or OS access is required for day-to-day use.

---

## 9. Networking Assumptions

* Outbound connectivity only
* No inbound ports required externally
* Devices publish *to* the Pi
* Pi may later publish *upstream* to cloud services

This makes the setup NAT-friendly and firewall-tolerant.

---

## 10. Failure Behaviour

| Event            | Expected Outcome               |
| ---------------- | ------------------------------ |
| Device offline   | No new telemetry               |
| MQTT restart     | Automatic reconnect            |
| InfluxDB restart | Short ingestion pause          |
| Pi reboot        | Stack auto-starts              |
| Network outage   | Local dashboards remain usable |

This aligns with a **store-locally, forward-later** philosophy.

---

## 11. Security Posture

### PoC Mode

* No TLS
* No MQTT authentication
* Local network only
* SSH key-based access

### Production Path

* TLS-enabled MQTT
* Device credentials or certificates
* Network segmentation
* Central authentication & audit

Security can be incrementally hardened **without changing architecture**.

---

## 12. When to Use This Model

Use when:

* Client has no automation backbone
* Speed of deployment matters
* Cost sensitivity is high
* Telemetry is low to moderate frequency

Avoid when:

* High-frequency control is required
* Safety-critical logic is involved
* Existing SCADA/historian already exists

---

## 13. Relationship to Other Docs

* **Architecture & role:**
  `hardware/raspberry-pi/notes/edge-gateway.md`
* **Runtime configs:**
  `infra/poc-stack/`
* **ESP32 devices:**
  `docs/hardware/esp32.md`

Each document answers a **different question**.

---

### ✅ Status

* Implemented
* Tested
* Aligned with PoC architecture
* Ready for client pilots

