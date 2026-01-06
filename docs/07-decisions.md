# DECISIONS.md

**Ironlink – PoC Decisions and Production Change Notes**

## 0. How to Read This

Each decision includes:

* **Decision** (what we chose)
* **Why** (why it fits the PoC / pilot goals)
* **Alternatives considered**
* **Production changes** (what we upgrade later)
* **Upgrade triggers** (clear conditions to change)

---

## 1. MQTT as Primary Telemetry Transport

**Decision:** Use **MQTT** as the standard transport for telemetry ingestion.

**Why:**

* Lightweight, reliable over flaky links (common at sites)
* Natural pub/sub model for machines/sites/fleets
* Broad ecosystem support (ESP32, gateways, Telegraf)

**Alternatives considered:**

* HTTP POST (simple but less resilient and chatty)
* AMQP (heavier, less common on edge devices)
* OPC-UA direct-to-cloud (great for PLCs, but not universal)

**Production changes:**

* Enforce **MQTT over TLS (8883)** (no plaintext)
* Add **topic-level ACLs** and **device identity**

**Upgrade triggers:**

* More than ~50–100 concurrent devices per client, or strict enterprise requirements → move to clustered broker (see Decision 2)

---

## 2. Broker Choice: Mosquitto (PoC) with Path to EMQX/HiveMQ

**Decision:** Use **Mosquitto** for PoC simplicity; keep broker abstraction so we can switch to **EMQX** (or HiveMQ) when needed.

**Why:**

* Fast to deploy and debug
* Minimal moving parts for demos
* Good enough for single-node PoC and early pilots

**Alternatives considered:**

* EMQX (more features: clustering, dashboards, richer auth)
* HiveMQ (enterprise-grade, often client-driven)

**Production changes:**

* Phase B/C: **EMQX cluster** (or HiveMQ if client mandates)
* Enable: mTLS, rate limiting, per-tenant ACLs

**Upgrade triggers:**

* Need HA, multi-region ingress, or strict RBAC on topics
* Broker becomes bottleneck (connection count, message rate)
* Clients require enterprise broker features

---

## 3. Edge Agent: Telegraf as Default

**Decision:** Use **Telegraf** as the default edge agent for consuming MQTT and writing to TSDB.

**Why:**

* Proven, lightweight, easy to run in Docker
* Supports MQTT consumer + parsing + basic processors
* Low-effort operationally (config-driven)

**Alternatives considered:**

* Node-RED (excellent for prototyping; can become messy at scale)
* Vector (great for logs/streams; needs more custom shaping for IoT)
* Custom agent (maximum control; higher engineering cost)

**Production changes:**

* Keep Telegraf for most sites
* Add a small **custom “Ironlink Agent”** only where:

  * complex protocol translation is needed
  * advanced buffering / local analytics is required

**Upgrade triggers:**

* Sites with frequent connectivity loss + strict no-loss requirements
* Need protocol adapters beyond Telegraf comfort (e.g., complex Modbus mapping)
* Need signed config updates + fleet management

---

## 4. Edge Buffering Strategy: Store-and-Forward on Gateway

**Decision:** Include **local buffering** (disk queue) at the edge for intermittent connectivity.

**Why:**

* Field reality: internet drops happen
* Prevents silent data gaps
* Makes demo credible for industrial ops

**Alternatives considered:**

* No buffering (simpler, but fragile and loses trust fast)
* Broker persistence only (doesn’t cover all failure modes)
* Full offline-first edge database (heavier)

**Production changes:**

* Enforce buffer limits, retention, compression
* Define replay policy (latest-first vs FIFO)
* Add alerting on backlog size / replay lag

**Upgrade triggers:**

* Backlog frequently hits cap
* Forensic/audit requirements: “prove data not lost”
* Sites offline for days at a time

---

## 5. Time-Series Storage: InfluxDB (PoC) with Timescale Option

**Decision:** Use **InfluxDB** for PoC time-series storage.

**Why:**

* Fast to stand up and query for dashboards
* Matches the PoC toolchain (Telegraf + Grafana)
* Good for quick iteration and demos

**Alternatives considered:**

* TimescaleDB (strong relational integration; SQL; easier joins)
* Prometheus/VictoriaMetrics (metrics-centric; less natural for arbitrary telemetry)

**Production changes:**

* Move to **InfluxDB 2.x** (tokens, orgs, better governance) OR
* Move to **TimescaleDB** if you need heavy relational joins (maintenance + telemetry)

**Upgrade triggers:**

* Need strict multi-tenant org isolation with governance controls
* Need more SQL-style analytics joining metadata and telemetry
* Need predictable long retention + downsampling pipelines

---

## 6. Metadata Storage: Add Postgres (Production)

**Decision:** PoC runs without a formal metadata DB; production adds **Postgres** for tenant/site/machine truth.

**Why:**

* PoC can rely on tags in telemetry + conventions
* Production needs relational integrity: users, tenants, devices, certificates

**Alternatives considered:**

* Keep everything as tags (breaks down as soon as you need governance)
* NoSQL (adds complexity without strong need early)

**Production changes:**

* Postgres tables:

  * tenants, sites, machines, machine_types
  * devices, credentials/certs
  * alert_rules, notification_routes
  * audit events (or forward to SIEM)

**Upgrade triggers:**

* More than one tenant
* Need device provisioning workflow
* Need consistent machine registry and lifecycle tracking

---

## 7. Ingress Layer: Explicit TLS Termination + Rate Limiting

**Decision:** Add an explicit **INGRESS** layer in production.

**Why:**

* Central point for security controls (TLS, throttling, IP allowlists)
* Decouples internet-facing endpoint from broker internals

**Alternatives considered:**

* Expose broker directly (works, but increases blast radius)
* VPN-only (secure but raises client friction)

**Production changes:**

* Ingress supports:

  * TLS termination (and optional mTLS)
  * rate limiting per device/tenant
  * basic request validation
  * metrics + logs

**Upgrade triggers:**

* Any internet-facing deployment
* Any client security review
* Need regional endpoints later

---

## 8. Tenant Isolation Model: Level 1 → Level 2 → Level 3

**Decision:** Start with **tenant_id tagging + RBAC** (Level 1), then evolve.

**Why:**

* Fast onboarding for pilots
* Avoids complex per-tenant infra early
* Keeps migration path open

**Alternatives considered:**

* Separate DB per tenant from day one (heavy, costly, slower)
* Separate full environment per tenant (best isolation, worst ops overhead)

**Production changes:**

* Level 2: separate Grafana orgs + scoped DB permissions/tokens
* Level 3: selective per-tenant DB/cluster for enterprise clients

**Upgrade triggers:**

* Client requires strict isolation
* You sell Enterprise tier with hard separation guarantees

---

## 9. Observability: Monitor the Platform Itself

**Decision:** Treat the monitoring platform as a monitored system.

**Why:**

* If ingestion fails silently, clients lose trust instantly
* Helps you run this as a real service (SLAs)

**Alternatives considered:**

* “We’ll look when it breaks” (doesn’t scale past 1 client)

**Production changes:**

* Monitor:

  * broker connections, message throughput, drops
  * pipeline lag and errors
  * TSDB write failures and disk usage
  * dashboard availability
* Central logs (Loki/ELK) and basic alerting

**Upgrade triggers:**

* As soon as you have paying clients
* Any 24/7 operational promise

---

## 10. Raw Payload Archival: Object Storage

**Decision:** Store **raw payloads** (or batches) in **OBJ** for replay/forensics and backups.

**Why:**

* Enables reprocessing if schema changes
* Supports audits and investigations
* Cheap long-term storage

**Alternatives considered:**

* Keep only TSDB (harder to reprocess; loses raw context)
* Store everything in TSDB forever (costly)

**Production changes:**

* Add lifecycle policies (e.g., 30 days raw, 1 year compressed batches)
* Store daily/hourly partitions by tenant/site/machine

**Upgrade triggers:**

* When you introduce schema versioning
* When clients request audit/failure investigations

---

## 11. Alerting Engine: Start Simple, Expand Later

**Decision:** Implement alerting based on:

* thresholds
* no-data
* state transitions

**Why:**

* High value early
* Requires minimal history
* Easy to explain to ops teams

**Alternatives considered:**

* ML anomaly detection (needs clean baseline history; slower to trust)

**Production changes:**

* Add escalation policies (WhatsApp/SMS/email)
* Add alert deduping, maintenance windows, silencing
* Add anomaly detection after sufficient baseline

**Upgrade triggers:**

* Too many false positives
* You have 30–90 days of clean telemetry for baseline modeling

---

## 12. Diagram Alignment

This decisions log aligns with the future-state diagram:

* Edge: `MACH → GW → (MQE + BUF) → AGENT`
* Cloud: `AGENT → INGRESS → MQC → PIPE → TSDB → GRAF/ALERTS`
* Governance: `AUTH → GRAF`, `AUTH → AUDIT`, `PIPE → OBJ`

---

## 13. What to Change First for Production

If moving from PoC to paid pilot, do these first:

1. **TLS everywhere** (INGRESS + MQC)
2. **Device identity + topic ACLs**
3. **Retention policies** (TSDB + OBJ lifecycle)
4. **Basic platform monitoring** (broker + pipeline + TSDB)
5. **Tenant RBAC** in Grafana

> **Where to tailor this:**
>
> * If your first clients are very security-heavy, move (2) to #1.
> * If your first clients are cost-sensitive, prioritize retention/lifecycle.


