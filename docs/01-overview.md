# Ironlink IoT Platform — Overview

## Purpose
Ironlink is a remote machinery monitoring platform designed to capture telemetry from industrial equipment across distributed sites and provide near real-time visibility through dashboards and alerts.

This repository documents:
- The **Proof of Concept (PoC)** implemented to validate end-to-end telemetry flow
- A **future-state architecture** that resembles the target production system
- The operational patterns needed to move from PoC → Pilot → Production

## What the PoC Proved
The PoC validated that we can:
- Publish telemetry from an edge device (ESP32 + sensor) using MQTT topics
- Ingest MQTT messages reliably using Telegraf
- Store time-series data in InfluxDB
- Visualize telemetry in Grafana with filtering and basic panel queries
- Run the stack via Docker on a Raspberry Pi (edge gateway)

## PoC Scope
Included:
- Single edge environment (home/lab)
- One sensor stream (e.g., temperature/humidity)
- MQTT → Telegraf → InfluxDB → Grafana pipeline
- Containerized services (Docker)

Excluded (planned for future):
- Multi-site ingestion over public networks
- Edge buffering for intermittent connectivity
- TLS device identity and certificate management
- Multi-tenant isolation (customer/site segregation)
- Alerting / notification engine (email/WhatsApp/SMS)
- PLC/SCADA integration (Modbus, OPC-UA, vendor protocols)

## Design Principles
- **Edge-first:** tolerate unreliable connectivity; capture locally, forward centrally
- **Protocol-agnostic:** accept telemetry via MQTT initially, expand to Modbus/OPC-UA
- **Tag-driven model:** support multi-site filtering via consistent tags (site/machine/device)
- **Secure by default:** TLS transport, least-privilege auth, auditable access
- **Operable:** clear runbooks, backups, and predictable deployments

## Repository Layout (high level)
- `docs/` — documentation for PoC and target system
- `diagrams/` — Mermaid architecture diagrams
- `edge/` — edge gateway and device-side components (to be added)
- `platform/` — central platform services (to be added)

## How to Use This Repo
1. Read `docs/02-architecture.md` for PoC + future-state architecture.
2. Use the PoC documentation to reproduce the setup and demo the data flow.
3. Use the future architecture to guide design decisions for a pilot deployment.

## Current Status
- Phase: **PoC**
- Next milestone: **Pilot-ready architecture** (secure ingestion, buffering, alerts)
