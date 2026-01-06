# POC_RUNBOOK.md

**Ironlink – Remote Machinery Monitoring (PoC Stack)**

## 1. Purpose of This Runbook

This document describes the **exact steps required to reproduce the Ironlink PoC stack** from a clean machine to a working end-to-end demo:

* Edge device publishes telemetry
* MQTT broker ingests messages
* Telegraf consumes MQTT
* InfluxDB stores time-series data
* Grafana visualizes metrics

**Scope:** Proof-of-Concept only
**Out of scope:** High availability, multi-tenant auth, enterprise security hardening

---

## 2. Target Architecture (PoC)

**Data Flow**

```
Sensor (ESP32 / Pi) 
→ MQTT (Mosquitto) 
→ Telegraf 
→ InfluxDB 
→ Grafana
```

---

## 3. Prerequisites

### 3.1 Infrastructure

You need **one Linux host** (VM or bare metal).

Tested on:

* Ubuntu 22.04 LTS
* Oracle Cloud / AWS / Local VM

Minimum specs:

* 2 vCPU
* 2 GB RAM (4 GB recommended)
* 20 GB disk

---

### 3.2 Software Required

Install these before proceeding:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git
```

---

### 3.3 Docker & Docker Compose

Install Docker:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
```

Verify:

```bash
docker --version
docker compose version
```

---

## 4. Repository Structure

Expected repo layout:

```
infra/
└── poc-stack/
    ├── docker-compose.yml
    ├── telegraf/
    │   └── telegraf.conf
    ├── mosquitto/
    │   ├── mosquitto.conf
    │   └── passwd
    └── influxdb/
        └── init/
```

> 🔧 **Change point:**
> In production, this folder would be split into:
>
> * `infra/edge`
> * `infra/cloud`
> * `infra/shared`

---

## 5. Environment Variables

Create a `.env` file inside `infra/poc-stack/`:

```env
INFLUXDB_DB=ironlink
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=admin123
INFLUXDB_USER=telegraf
INFLUXDB_USER_PASSWORD=telegraf123
```

> 🔐 **Change point:**
>
> * Replace plaintext secrets with Vault / SSM in prod
> * Enforce password rotation
> * Use per-tenant DBs later

---

## 6. MQTT Broker (Mosquitto)

### 6.1 Mosquitto Config

Confirm `mosquitto/mosquitto.conf` includes:

```conf
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest stdout
```

> 🔧 **Change point:**
>
> * Disable anonymous access in prod
> * Add TLS on port 8883
> * Enforce topic-level ACLs

---

### 6.2 Topic Convention (PoC Standard)

```
ironlink/{domain}/{site}/{machine}/telemetry
```

Example:

```
ironlink/weld/SITE-A/A-M01/telemetry
```

Payload (JSON):

```json
{
  "site": "SITE-A",
  "machine": "A-M01",
  "ts": 1763932401,
  "temp_c": 42.3,
  "feeder_a": 12.4
}
```

> 🔧 **Change point:**
>
> * Add schema registry in prod
> * Enforce required fields per machine type

---

## 7. Telegraf (MQTT Consumer)

### 7.1 Telegraf Input

Confirm `telegraf.conf` contains:

```toml
[[inputs.mqtt_consumer]]
  servers = ["tcp://mosquitto:1883"]
  topics = ["ironlink/#"]
  data_format = "json"
  tag_keys = ["site", "machine"]
```

### 7.2 Telegraf Output

```toml
[[outputs.influxdb]]
  urls = ["http://influxdb:8086"]
  database = "ironlink"
  username = "telegraf"
  password = "telegraf123"
```

> 🔧 **Change point:**
>
> * One Telegraf per site in prod
> * Use InfluxDB v2 + tokens later
> * Add buffering for offline edge sites

---

## 8. InfluxDB

### 8.1 Version

PoC uses:

* **InfluxDB 1.8.x**

Reason:

* Simpler setup
* Compatible with Grafana without Flux
* Faster iteration for demos

> 🔄 **Change point:**
> In production, migrate to **InfluxDB 2.x** for:
>
> * Native auth tokens
> * Better retention policies
> * Fine-grained org/project separation

---

### 8.2 Verify Database

After stack is running:

```bash
docker exec -it influxdb influx
```

```sql
SHOW DATABASES;
USE ironlink;
SHOW MEASUREMENTS;
```

---

## 9. Grafana

### 9.1 Access

Default URL:

```
http://<HOST_IP>:3000
```

Default credentials:

```
admin / admin
```

### 9.2 Add InfluxDB Data Source

* Type: InfluxDB
* URL: `http://influxdb:8086`
* Database: `ironlink`
* User: `admin`
* Password: `admin123`

---

### 9.3 Dashboard Query Example

```sql
SELECT mean("temp_c")
FROM "mqtt_consumer"
WHERE $timeFilter
GROUP BY time($__interval), "machine"
```

> 🔧 **Change point:**
>
> * Pre-build dashboards per machine class
> * Add alert rules in prod
> * Add RBAC per client

---

## 10. Running the Stack

From `infra/poc-stack/`:

```bash
docker compose pull
docker compose up -d
```

Verify:

```bash
docker ps
```

All containers should be **healthy**.

---

## 11. Publishing Test Data

### 11.1 From the Host

```bash
docker exec -it mosquitto \
mosquitto_pub \
  -t ironlink/weld/SITE-A/A-M01/telemetry \
  -m '{"site":"SITE-A","machine":"A-M01","temp_c":45.2,"feeder_a":11.9}'
```

### 11.2 Verify InfluxDB

```sql
SELECT * FROM mqtt_consumer ORDER BY time DESC LIMIT 5;
```

---

## 12. Success Criteria (PoC Complete)

✅ MQTT messages received
✅ Telegraf consumes topics
✅ Data visible in InfluxDB
✅ Grafana shows live charts
✅ New machines appear automatically via tags

---

## 13. Known PoC Limitations

* No authentication between services
* Single-node only
* No data retention policy
* No alert escalation
* No edge buffering

These are **intentional** for speed.

