# Ironlink IoT Platform

**Remote machinery monitoring & edge telemetry platform**
*Edge-first. Production-minded. Built for real industrial constraints.*

---

## Overview

The **Ironlink IoT Platform** is an edge-centric monitoring platform designed to ingest telemetry from industrial equipment and sensors, store it reliably, and expose actionable visibility through dashboards and alerts.

Release Reality (Read This First)

Ironlink follows an incremental hardening model:

- v0.1.x — Proof of Concept (PoC)
- v0.2.x — Edge production readiness (monitoring)
- v0.3.x — Cloud ingestion & secure transport
- v1.0.0 — General availability

Each release explicitly documents what is guaranteed and what is out of scope.
See `docs/08-v0.2.0-readiness.md` for operational guarantees.


The platform is intentionally designed to:

* Work **with or without PLCs / SCADA**
* Support **low-connectivity and remote sites**
* Scale from **PoC → pilot → production**
* Separate **hardware**, **edge**, and **cloud** concerns cleanly

This repository contains:

* Architecture definitions
* Hardware configurations
* Edge gateway provisioning
* PoC runtime stack
* Operational documentation

---

## Current Status

**Milestone:** `v0.2.0-edge-prod`

Implemented and validated:

* ESP32 sensor node publishing MQTT telemetry
* Raspberry Pi edge gateway
* Local MQTT ingestion
* Time-series storage (InfluxDB)
* Dashboards (Grafana)
* Automated provisioning for edge gateways

This milestone is production-ready for edge-only monitoring deployments
(10–100 sites), with deterministic provisioning, enforced device identity,
and verified end-to-end telemetry ingestion.

Cloud ingestion, TLS-secured WAN messaging, and store-and-forward buffering
are intentionally deferred to v0.3.0.


---

## Architecture (High Level)

```text
ESP32 / Sensors
      ↓ MQTT
Raspberry Pi Edge Gateway
      ├── Mosquitto (MQTT)
      ├── Telegraf (Ingestion)
      ├── InfluxDB (Time-series)
      └── Grafana (Dashboards)
```

Future architecture introduces:

* Secure cloud ingestion
* Multi-tenant separation
* Central alerting and analytics
* PLC / VFD integrations

See:

* `diagrams/poc-architecture.mmd`
* `diagrams/future-architecture.mmd`

---

## Repository Structure

```text
.
├── diagrams/              # Architecture diagrams (Mermaid)
├── docs/                  # Platform & operational documentation
│   └── hardware/          # Hardware-specific docs
├── hardware/              # Device & gateway configurations
│   ├── esp32/             # Sensor node firmware & config
│   └── raspberry-pi/      # Edge gateway notes & provisioning
├── infra/
│   └── poc-stack/         # Docker-based PoC runtime stack
└── README.md
```

**Separation of concerns is intentional and enforced.**

---

## Hardware Support

### ESP32 – Sensor Node

* Publishes JSON telemetry over MQTT
* Designed for low-cost, rapid deployment
* No inbound connections required

Docs:

* `docs/hardware/esp32.md`
* Firmware: `hardware/esp32/firmware/`

Secrets handling:

* `secrets.example.h` → committed
* `secrets.h` → local only (ignored)

---

### Raspberry Pi – Edge Gateway

* Runs local ingestion and dashboards
* Designed for sites with no PLC/SCADA
* Fully containerised

Docs:

* `docs/hardware/raspberry-pi.md`
* Architectural role: `hardware/raspberry-pi/notes/edge-gateway.md`

Provisioning:

* Script: `hardware/raspberry-pi/provision/provision.sh`
* Env template: `hardware/raspberry-pi/provision/provision.env.example`

---

## Getting Started (Edge Deployment)

For production-style site onboarding, follow:
docs/runbooks/NEW_SITE_BRINGUP.md


### 1. Provision the Edge Gateway

```bash
cd hardware/raspberry-pi/provision
cp provision.env.example provision.env
# edit provision.env for the site
./provision.sh
```

After provisioning:

* Grafana: `http://<PI-IP>:3000`
* MQTT: `tcp://<PI-IP>:1883`

---

### 2. Flash an ESP32

1. Copy secrets:

   ```bash
   cp hardware/esp32/config/secrets.example.h \
      hardware/esp32/config/secrets.h
   ```
2. Edit WiFi, MQTT broker, and device ID
3. Flash firmware:

   ```
   hardware/esp32/firmware/esp32_dht11_mqtt.ino
   ```

Telemetry should appear in Grafana within seconds.

---

## Documentation Index

| Topic               | File                             |
| ------------------- | -------------------------------- |
| Platform overview   | `docs/01-overview.md`            |
| Architecture        | `docs/02-architecture.md`        |
| PoC setup           | `docs/03-poc-setup.md`           |
| PoC runbook         | `docs/04-poc-runbook.md`         |
| Future architecture | `docs/05-architecture_future.md` |
| Operations          | `docs/06-operational-runbook.md` |
| Design decisions    | `docs/07-decisions.md`           |
| Production-ready    | `docs/08-v0.2.0-readiness.md`    |

---

## Design Principles

* **Edge first** – tolerate poor connectivity
* **Observable by default** – dashboards before analytics
* **Incremental security** – PoC → hardened without rewrites
* **Hardware-agnostic** – sensors today, PLCs tomorrow
* **Operational clarity** – technicians can deploy this

---

## What This Is (and Isn’t)

### This **is**

* A real, deployable PoC platform
* A foundation for SaaS or managed monitoring
* Suitable for pilots and early clients

### This **is not**

* A real-time control system
* A PLC replacement
* A safety-critical control stack

---

## Roadmap (High Level)

Planned next steps:

* Telemetry schema standardisation
* Device provisioning registry
* Secure MQTT (TLS + auth)
* PLC / welding machine adapters
* Central cloud ingestion
* Alerting & anomaly detection

---

## Versioning

This repository uses **semantic versioning with scope tags**.

Example:

* `v0.1.0-edge-poc` 
* `v0.2.0-edge-prod` – current milestone
* `v0.3.0-cloud-ingest`
* `v1.0.0-ga`

---

## License & Usage

License to be defined.
For client pilots or commercial use, contact the project owner.

---

## Maintainer

**Ironlink Engineering (Pty) Ltd**
Remote monitoring & industrial data systems

