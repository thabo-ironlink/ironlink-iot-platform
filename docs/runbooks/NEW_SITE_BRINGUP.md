# Runbook: New Site Bring-Up (v0.2.0 Edge)

## Goal
Bring a new edge gateway online and confirm end-to-end telemetry ingestion with correct fleet identity tags.

A site is considered **LIVE** when:
- Provisioning completes successfully
- Docker containers are healthy
- A telemetry point is visible in InfluxDB **with identity tags**:
  - client_id, site_id, gateway_id, environment, hostname

---

## 1) Clone + pin the release

```bash
cd ~
git clone https://github.com/thabo-ironlink/ironlink-iot-platform.git
cd ironlink-iot-platform
git checkout release/v0.2.0-edge-prod
git describe --tags --exact-match
```
Expected:
```bash
v0.2.0-edge-prod
```

## 2) Create site config (DO NOT COMMIT)
```bash
cd hardware/raspberry-pi/provision
cp provision.env.example provision.env
nano provision.env
```

Set at minimum:
```bash
IRONLINK_ENVIRONMENT=prod
IRONLINK_CLIENT_ID=<CLIENT-ID>      # e.g. ZAM-WELD
IRONLINK_SITE_ID=<SITE-ID>          # e.g. SITE-A
IRONLINK_GATEWAY_ID=<GW-ID>         # e.g. GW-01
IRONLINK_HOSTNAME=<SITE-GW-HOSTNAME># e.g. SITE-A-GW-01
```

Optional:
```bash
IRONLINK_TIMEZONE=Africa/Johannesburg
IRONLINK_START_STACK=1
IRONLINK_ENABLE_UFW=0
```

## 3) Run provisioning
```bash
set -a
source provision.env
set +a

./provision.sh
```

What this should do:
- sets hostname + timezone
- installs Docker + docker-compose if needed
- disables conflicting host services (mosquitto/influxdb/grafana-server)
- starts the docker stack from infra/poc-stack

## 4) Verify containers
```bash
cd ~/ironlink-iot-platform/infra/poc-stack
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected containers:
- mosquitto (1883)
- influxdb (8086)
- grafana (3000)
- telegraf

## 5) Smoke test telemetry (MQTT -> Influx)

Publish a known test payload:
```bash
mosquitto_pub -h localhost \
  -t "ironlink/env/HOME/esp32/dht11" \
  -m '{"temp_c":25.2,"humidity":55,"ts":'$(date +%s)'}'
```

Wait ~10 seconds.

Query Influx:
```bash
sudo docker exec -it influxdb influx \
  -username 'ironadmin' \
  -password 'SuperSecretPass123' \
  -database 'telemetry' \
  -execute 'SELECT * FROM mqtt_consumer ORDER BY time DESC LIMIT 5'
```

Expected:
- At least one row
- Identity tags present:
  - client_id, site_id, gateway_id, environment, hostname
- topic tag matches the topic you published to

## 6) Troubleshooting quick hits
### A) No data in Influx
```bash
sudo docker logs --tail 120 telegraf
```
Look for write/auth errors or parse errors.

### B) Can’t bind ports (1883/8086/3000)
```bash
sudo ss -ltnp | egrep ':1883|:8086|:3000'
```

If host services are holding ports:
```bash
sudo systemctl disable --now mosquitto influxdb grafana-server || true
sudo docker-compose up -d
```

### C) Identity tags missing
Confirm telegraf received env vars:
```bash
sudo docker exec -it telegraf printenv | egrep 'IRONLINK_|HOSTNAME'
```

## 7) Close-out checklist
- [ ] provision.env exists and contains correct identity for this site
- [ ] Containers healthy
- [ ] Telemetry visible with identity tags in Influx
- [ ] Site recorded in internal tracker (client/site/gateway + IP + install date)

### Where to customize later
- Topic patterns: change `topics = [...]` in `infra/poc-stack/telegraf/telegraf.conf`
- Credentials: move away from inline passwords (v0.3.0 hardening)
- Networking: enable UFW and allow only required inbound ports per customer policy

---

