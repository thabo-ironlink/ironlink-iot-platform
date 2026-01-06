# PoC Setup — InfluxDB & Grafana (Docker)

This document describes the exact Proof of Concept (PoC) setup used to validate Ironlink’s end-to-end telemetry ingestion and visualization pipeline.

The PoC runs locally on a single host (e.g. Raspberry Pi or laptop) using Docker Compose.

---

## 1) Host Environment

### Tested Environment
- OS: Linux (Raspberry Pi OS / Ubuntu) or Windows (Docker Desktop)
- Container runtime: Docker
- Orchestration: Docker Compose v3.8

### Assumptions
- Docker and Docker Compose are installed
- Ports `3000` (Grafana) and `8086` (InfluxDB) are available on the host

---

## 2) Services Overview

| Service   | Purpose                          | Port | Notes |
|----------|----------------------------------|------|------|
| InfluxDB | Time-series storage (telemetry)  | 8086 | InfluxDB v1.8 (PoC) |
| Grafana  | Dashboards & visualization       | 3000 | Latest Grafana image |

---

## 3) Docker Compose Configuration

### `docker-compose.yml`
```yaml
version: "3.8"

services:
  influxdb:
    image: influxdb:1.8
    container_name: influxdb
    restart: unless-stopped
    ports:
      - "8086:8086"
    environment:
      - INFLUXDB_DB=telemetry
      - INFLUXDB_HTTP_AUTH_ENABLED=true
      - INFLUXDB_ADMIN_USER=ironadmin
      - INFLUXDB_ADMIN_PASSWORD=SuperSecretPass123
    volumes:
      - ./influxdb-data:/var/lib/influxdb

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=AnotherStrongPass123
```
## Known Issues / Troubleshooting
### Troubleshooting: `docker compose` vs `docker-compose`
On this host, Docker Compose v2 (`docker compose`) is not available, so we use Compose v1:

- Use: `docker-compose up -d`
- Avoid: `docker-compose up -d --force-recreate ...` (may trigger `KeyError: 'ContainerConfig'`)

If a container needs recreating, remove it and bring it back:
```bash
docker rm -f <container_name>
docker-compose up -d <service>
```

### Troubleshooting: InfluxDB CLI query syntax

For InfluxDB 1.8, prefer -database telemetry rather than USE telemetry; in a single execute string:
```bash
docker exec -it influxdb influx -username <user> -password <pass> \
  -database telemetry \
  -execute "SELECT * FROM mqtt_consumer ORDER BY time DESC LIMIT 5"
```

### Known transient issue: Docker DNS inside containers

If Telegraf logs show:

- lookup mosquitto on 127.0.0.11:53: server misbehaving

Action:

- ensure all services share the same user-defined network

- restart telegraf:
```bash
docker-compose restart telegraf
```

---

## 3) Commit your stack into GitHub (so anyone can reproduce it)
From the repo root (where `docker-compose.yml`, `mosquitto/`, `telegraf/` live):

```bash
git add docker-compose.yml mosquitto telegraf docs
git commit -m "feat: codify full poc stack (mosquitto+telegraf+influxdb+grafana) and runbook"
git push
```