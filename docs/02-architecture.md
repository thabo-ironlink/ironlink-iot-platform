# Architecture

This document contains:
1) The **PoC architecture** that is currently implemented  
2) The **future-state architecture** that resembles the target production system

---

## 1) Proof of Concept (PoC) Architecture

### Summary
The PoC demonstrates end-to-end telemetry flow from a sensor device to a dashboard using MQTT, Telegraf, InfluxDB, and Grafana.

### Components (PoC)
- **Telemetry source:** ESP32 + sensor (e.g., DHT11)
- **Transport:** MQTT (Mosquitto)
- **Ingestion:** Telegraf (`mqtt_consumer`)
- **Storage:** InfluxDB (PoC instance)
- **Visualization:** Grafana
- **Runtime:** Docker (Raspberry Pi as host)

### Data flow (PoC)
1. ESP32 publishes JSON telemetry to an MQTT topic
2. Telegraf subscribes to one or more MQTT topics
3. Telegraf parses JSON fields and writes time-series points to InfluxDB
4. Grafana queries InfluxDB and renders dashboards

### PoC Diagram
See: `diagrams/poc-architecture.mmd`

### PoC constraints
- Single site (lab)
- Local-only stack (no multi-region/tenant separation)
- No edge buffering beyond defaults
- No formal device identity or TLS transport (unless explicitly enabled)

---

## 2) Target Production Architecture (Future State)

### Objectives
- Support **multiple sites** and **multiple machine types**
- Secure ingestion over public networks (TLS, device identity)
- Tolerate intermittent connectivity (edge buffering + resend)
- Provide multi-tenant dashboards and access control
- Enable alerting, reporting, and APIs for integrations

### Future-state building blocks
#### Edge (per site)
- Edge gateway capable of:
  - Protocol translation (MQTT, Modbus, OPC-UA)
  - Local buffering (disk queue) during network outages
  - Secure authentication to the central platform

#### Central platform (cloud / VPS / customer DC)
- Ingress endpoint (TLS termination, rate limiting, WAF optional)
- MQTT cluster (or ingestion gateway) with authentication
- Ingestion pipeline (routing, validation, enrichment)
- Time-series database with retention + backups
- Visualization (Grafana) with multi-tenant segmentation
- Alerting engine (rules + notifications)
- Audit logging and role-based access control (RBAC)

### Multi-tenancy model
At minimum, enforce separation by tags:
- `customer`
- `site`
- `machine`
- `device_id`

### Future Diagram
See: `diagrams/future-architecture.mmd`

---

## 3) Standardization Guidance (start now, saves pain later)

### Topic naming convention (recommended)
Use a consistent topic hierarchy:
- `ironlink/<domain>/<site>/<machine>/telemetry`
Examples:
- `ironlink/weld/SITE-A/A-M01/telemetry`
- `ironlink/env/HOME/iot-pi/dht11`

### Telemetry envelope (recommended)
Add standard fields for all messages:
- `ts` (epoch seconds) — if device-supplied; otherwise use ingestion timestamp
- `site`, `machine`, `device_id`
- `status` / `fault` when available (especially for industrial equipment)

### Data tags vs fields
- Put identifiers in **tags** (customer/site/machine/device_id)
- Put measurements in **fields** (temp_c, humidity, current_a, vibration_rms)

---

## 4) PoC → Pilot → Production (high-level)
- **PoC:** prove telemetry pipeline and dashboards (done)
- **Pilot:** secure ingestion + buffering + alerting + multi-site rollout
- **Production:** multi-tenant RBAC, auditability, CI/CD, SLAs, observability
