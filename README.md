# ironlink-iot-platform
End-to-end IoT &amp; remote machinery monitoring platform for industrial equipment. Edge ingestion, secure telemetry, time-series storage, dashboards, and alerts.

# Ironlink Platform

Ironlink is a modular IoT and remote machinery monitoring platform designed for industrial and heavy-equipment environments.

The platform enables secure telemetry ingestion from edge devices (ESP32, PLCs, gateways), centralized time-series storage, real-time dashboards, and operational alerting across multiple sites and regions.

## Current Status
- Proof of Concept (PoC)
- Single-edge site deployment
- MQTT → Telegraf → InfluxDB → Grafana pipeline

## Core Capabilities
- Edge telemetry ingestion (MQTT, sensor-based, PLC-ready)
- Time-series data storage
- Real-time visualization
- Modular, containerized deployment
- Designed for low-connectivity industrial environments

## Architecture (PoC)
See `docs/02-architecture.md` and `diagrams/poc-architecture.mmd`

## Roadmap
- Secure multi-site ingestion (TLS, device identity)
- Edge buffering and offline resilience
- Multi-tenant dashboards
- Alerting and notification engine
- PLC/SCADA integrations (Modbus, OPC-UA)

## Tech Stack
- ESP32 / Edge sensors
- MQTT (Mosquitto)
- Telegraf
- InfluxDB
- Grafana
- Docker

## License
**CHOOSE LATER** (MIT for now is fine)

