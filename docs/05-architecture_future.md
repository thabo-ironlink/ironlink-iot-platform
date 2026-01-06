# ARCHITECTURE_FUTURE.md

**Ironlink – Future-State Architecture (Production Target)**

## 1. Future-State Goals

The production architecture must support:

* **Multi-site, multi-machine** deployments across regions/countries
* **Multi-tenant separation** (client isolation: data, dashboards, access)
* **Secure ingestion** (device identity, TLS, authN/authZ)
* **Edge resilience** (offline buffering, store-and-forward)
* **Operational reliability** (monitoring, alerting, auditability)
* **Extensibility** (new machine types, new telemetry schemas, new analytics)

> 🔧 **Change point:** You can prioritize *speed-to-market* vs *enterprise-grade* by adopting the “Phase path” in Section 3.

---

## 2. System Overview

### 2.1 High-level Data Flow

**Edge**

* Sensors/PLC/SCADA/ESP32/RPi publish telemetry
* Local gateway performs validation + buffering
* Gateway forwards to cloud broker using secure transport

**Cloud**

* Cloud broker receives telemetry
* Stream processing normalizes/enriches
* Time-series + relational stores persist
* Dashboards + alerting provide operations view
* APIs enable downstream apps + integrations

---

## 3. Phased Architecture Path

This keeps you moving while still converging on the right end-state.

### Phase A: “PoC+” (1–2 clients)

* Single cloud environment
* TLS for MQTT
* Basic tenant tagging and access controls
* Simple retention and backups

### Phase B: “Commercial MVP” (3–20 clients)

* Per-tenant org separation in dashboards
* Device registry + provisioning
* Edge buffering + retries
* Central auth (SSO optional)

### Phase C: “Scale” (20+ clients, multiple regions)

* Regional ingestion endpoints
* High availability broker + storage
* Fleet management at scale
* Formal SLAs, audit trails, compliance posture

> 🔧 **Change point:** If you want to sell “as-a-service” quickly, implement Phase A+B first and defer full HA to Phase C.

---

## 4. Future-State Components

## 4.1 Edge Layer

### 4.1.1 Device Types Supported

* ESP32/Raspberry Pi sensors
* PLC/SCADA data via Modbus RTU/TCP, OPC-UA, vendor protocols
* Existing machine controllers via serial/RS485 gateways

### 4.1.2 Edge Gateway Responsibilities

The edge gateway becomes the “contract boundary” between messy industrial reality and clean cloud ingestion:

* **Protocol adapters:** Modbus, OPC-UA, MQTT, HTTP, serial
* **Normalization:** convert vendor signals → canonical telemetry fields
* **Schema validation:** enforce required fields, types, bounds
* **Buffering:** store-and-forward when internet drops
* **Compression & batching:** reduce bandwidth costs
* **Secure identity:** device certificates/keys

**Recommended edge runtime options**

* Lightweight: Telegraf + custom parser + MQTT forwarder
* More control: Node-RED / Python agent (only when needed)
* Best long-term: a small “Ironlink Agent” (container) with plugins

> 🔧 **Change point:** If your clients already have PLC/SCADA, you can position Ironlink as “data tap + cloud layer” and only deploy a gateway.

---

## 4.2 Ingestion Layer (Cloud Entry Point)

### 4.2.1 Message Broker

**MQTT broker** remains the default ingestion for telemetry.

**Production requirements:**

* TLS (8883), mutual TLS where possible
* AuthN: certs or tokens
* AuthZ: topic-level ACLs
* Rate limiting + quotas
* High availability (clustered broker)

**Swap options (choose by phase):**

* Phase A/B: Mosquitto (hardened) or EMQX (easier enterprise features)
* Phase C: EMQX cluster or HiveMQ (if clients demand it)

> 🔧 **Change point:** You can keep MQTT topics stable forever, even if you later change brokers. Treat MQTT topic design as a long-lived contract.

---

## 4.3 Stream Processing & Normalization

This is where raw telemetry becomes consistent and analytics-ready.

### 4.3.1 Processing Responsibilities

* Enrich tags: `tenant_id`, `site_id`, `machine_id`, `machine_type`
* Parse payload versions (v1, v2…)
* Detect missing/invalid values
* Map vendor-specific signals to canonical names
* Compute derived metrics (duty cycle, uptime %, temp deltas)

### 4.3.2 Implementation Options

* Phase A: Telegraf processors + minimal transforms
* Phase B: A small “ingestion service” (container) subscribed to topics
* Phase C: Event streaming (Kafka/NATS) + processors (Flink/Spark), if needed

> 🔧 **Change point:** Don’t overbuild Kafka early. Introduce it only when you need replay, large fan-out, or strict event contracts.

---

## 4.4 Storage Layer

Production typically needs **two storage types**:

### 4.4.1 Time-Series DB (Telemetry)

Stores high-volume metrics (temp, current, state, vibration, etc.)

Options:

* InfluxDB 2.x (tokens, orgs, better governance)
* TimescaleDB (Postgres-based, easier joins)
* VictoriaMetrics / Prometheus (metrics-centric)

**Recommended path**

* Move from InfluxDB 1.8 → InfluxDB 2.x (Phase B)
* Introduce retention policies per tenant and per metric type

### 4.4.2 Relational DB (Metadata)

Stores slower-moving system truth:

* tenants, sites, machines
* device identities & certificates
* alert rules and notification routing
* user roles & permissions
* maintenance events, work orders, notes

Recommended: Postgres

> 🔧 **Change point:** Keep “telemetry” and “metadata” separate. Telemetry is write-heavy and time-bucketed; metadata needs relational integrity.

---

## 4.5 API Layer (Productization)

Expose controlled access to:

* Machines, sites, latest status
* Timeseries queries (bounded + rate-limited)
* Alerts history
* Maintenance logs

Recommended approach:

* REST first (simple adoption)
* Add WebSockets later for live feeds
* Consider GraphQL only if frontend needs it

---

## 4.6 Visualization & Alerting

### 4.6.1 Dashboards

Grafana remains the UI backbone:

* per-tenant dashboards
* per-machine drilldowns
* fleet overview per site/region
* templated dashboards by machine type

### 4.6.2 Alerting

Alerting should be driven by:

* thresholds (temp > X)
* state transitions (running → stopped)
* statistical anomalies (vibration deviation)
* data absence (no telemetry for N minutes)

Notification channels:

* Email
* WhatsApp (via provider)
* SMS (fallback)
* Teams/Slack for ops

> 🔧 **Change point:** Start with simple threshold + no-data alerts; add anomaly detection after you’ve got enough clean historical data.

---

## 5. Multi-Tenancy Model

You need a clear tenant separation strategy early.

### 5.1 Tenant Isolation Levels

**Level 1 (fast):** tenant_id tag + RBAC in Grafana
**Level 2:** separate orgs in Grafana + scoped tokens in TSDB
**Level 3 (strict):** separate databases (or separate clusters) per tenant

Recommended:

* Phase A: Level 1
* Phase B: Level 2
* Phase C: selective Level 3 for large enterprise clients

> 🔧 **Change point:** If a client demands hard isolation, you can move only *that* tenant to Level 3 without reworking everyone else.

---

## 6. Security Architecture

### 6.1 Device Identity & Provisioning

* Every gateway/device has a unique identity
* Provisioning methods:

  * manual enrollment (Phase A)
  * QR-code/claim token (Phase B)
  * certificate-based zero-touch (Phase C)

### 6.2 Transport Security

* MQTT over TLS (8883)
* Optional mutual TLS for industrial clients
* Rotate certs/keys
* Block plaintext ingestion in production

### 6.3 Authorization

* Topic ACLs enforce tenant boundaries:

  * devices may publish only to `ironlink/<tenant>/<site>/<machine>/telemetry`
* Services get read-only subscribe permissions
* Users access via Grafana SSO/RBAC

### 6.4 Auditability

* Log: provisioning events, auth failures, admin actions, alert changes

---

## 7. Reliability & Resilience

### 7.1 Edge Offline Operation

* Buffer telemetry locally (disk)
* Retry with backoff
* Send latest state first, then backfill
* Cap backlog to avoid disk exhaustion

### 7.2 Cloud High Availability

* Broker clustering (active-active)
* TSDB replication/backups
* Infrastructure-as-code deployments
* Blue/green updates for ingestion services

### 7.3 Data Retention Strategy

Define retention tiers:

* raw telemetry: 7–30 days
* downsampled aggregates: 6–24 months
* key events/alerts: 2–5 years

> 🔧 **Change point:** Retention is a business lever. You can offer tiers (basic vs premium) without changing ingestion.

---

## 8. Observability & Operations

### 8.1 Monitoring

Monitor the platform itself:

* broker connections, message rates, dropped packets
* ingestion lag, processing errors
* TSDB write errors, disk usage
* Grafana availability
* per-tenant traffic and quotas

### 8.2 Logs & Tracing

* Central logs (Loki/ELK)
* Structured logs from ingestion services
* Traces only when you introduce multiple microservices

---

## 9. Deployment Model

### 9.1 Environments

* dev
* staging
* prod

### 9.2 Deployment Options

* Single VM (Phase A)
* Docker Swarm / lightweight K8s (Phase B)
* Kubernetes + IaC (Phase C)

> 🔧 **Change point:** You can keep the same containers and configs; only orchestration changes.

---

## 10. Canonical Telemetry Contract

Standardize on a stable canonical schema (versioned).

Minimum required fields:

* `tenant_id`, `site_id`, `machine_id`
* `ts` (epoch seconds)
* `status` (running/stopped/fault)
* machine metrics (vary by machine_type)

Versioning approach:

* payload contains `schema_version`
* processors map older versions forward

> 🔧 **Change point:** Canonical schema is the core product moat. Every integration becomes easier once this is stable.

---

## 11. What This Enables (Business Outcomes)

* Fleet uptime reporting per client
* Automated downtime detection (no-data + state changes)
* Predictive maintenance (once history accumulates)
* SLA dashboards for enterprise clients
* Usage-based pricing (messages, machines, sites)


