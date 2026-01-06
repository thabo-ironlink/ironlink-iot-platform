# Raspberry Pi Edge Gateway – Provisioning Guide

**Ironlink IoT Platform**

This guide explains **how to provision a Raspberry Pi** as an Ironlink **edge gateway** using the provided `provision.sh` script.

It is written for:

* Engineers
* Technicians
* Partners
* Internal deployments

No deep Linux knowledge is required.

---

## 1. What This Provisioning Does

The provisioning script prepares a Raspberry Pi to act as an **Ironlink edge gateway** by:

* Updating the operating system
* Installing required system tools
* Installing Docker and Docker Compose
* Setting the device hostname
* (Optionally) enabling a basic firewall
* (Optionally) starting the Ironlink PoC stack:

  * Mosquitto (MQTT)
  * Telegraf
  * InfluxDB
  * Grafana

After completion, the Pi is ready to receive telemetry from ESP32 devices.

---

## 2. Prerequisites

### Hardware

* Raspberry Pi 4 or 5 (tested on Pi 5)
* 64GB SD card recommended
* Stable power supply
* Ethernet or WiFi access

### Software

* Raspberry Pi OS Lite (64-bit)
* SSH enabled
* A user with `sudo` access

> ⚠️ No desktop environment is required.

---

## 3. Repository Location

This provisioning setup assumes the following repo layout:

```
ironlink-iot-platform/
├── infra/poc-stack/
│   └── docker-compose.yml
└── hardware/raspberry-pi/provision/
    ├── provision.sh
    └── README.md
```

Do **not** move `provision.sh` unless you also update paths inside the script.

---

## 4. Make the Script Executable

From the repo root:

```bash
chmod +x hardware/raspberry-pi/provision/provision.sh
```

---

## 5. Basic Provisioning (Recommended for PoC)

Run the script with default settings:

```bash
./hardware/raspberry-pi/provision/provision.sh
```

This will:

* Set hostname to `iot-pi`
* Install Docker
* Start the PoC stack
* Expose Grafana, InfluxDB, and MQTT locally

---

## 6. Customising for a Site or Client

You can customise behaviour using environment variables **before running the script**.

### Common examples

#### Set a site-specific hostname

```bash
IRONLINK_HOSTNAME=SITE-A-GW-01 \
./hardware/raspberry-pi/provision/provision.sh
```

#### Provision only (do not start containers yet)

```bash
IRONLINK_START_STACK=0 \
./hardware/raspberry-pi/provision/provision.sh
```

#### Use a different stack directory

```bash
IRONLINK_STACK_DIR=infra/prod-stack \
./hardware/raspberry-pi/provision/provision.sh
```

#### Enable firewall (recommended for production pilots)

```bash
IRONLINK_ENABLE_UFW=1 \
./hardware/raspberry-pi/provision/provision.sh
```

#### Reboot automatically after provisioning

```bash
IRONLINK_REBOOT=1 \
./hardware/raspberry-pi/provision/provision.sh
```

---

## 7. After Provisioning (Important)

### Docker group access

If this is the first time Docker was installed:

* **Log out and log back in**
* This allows running `docker` without `sudo`

### Verify services

Run:

```bash
docker ps
```

You should see containers for:

* Mosquitto
* Telegraf
* InfluxDB
* Grafana

---

## 8. Accessing Local Services

Replace `<PI-IP>` with the Raspberry Pi’s IP address.

| Service  | URL                   |
| -------- | --------------------- |
| Grafana  | `http://<PI-IP>:3000` |
| InfluxDB | `http://<PI-IP>:8086` |
| MQTT     | `tcp://<PI-IP>:1883`  |

Grafana is the **primary operational interface**.

---

## 9. Validating the Setup

### Test MQTT ingestion

From the Pi or another device on the same network:

```bash
mosquitto_pub -h <PI-IP> \
  -t "ironlink/env/HOME/test" \
  -m '{"temp_c":25,"humidity":50}'
```

If successful:

* Data appears in InfluxDB
* Dashboard updates in Grafana

---

## 10. Common Issues & Fixes

| Issue                    | Fix                         |
| ------------------------ | --------------------------- |
| Docker permission denied | Log out & back in           |
| Containers not starting  | Check `docker compose logs` |
| Cannot access Grafana    | Check firewall or IP        |
| MQTT not receiving       | Confirm port 1883 and topic |

---

## 11. When to Re-Run Provisioning

You can safely re-run `provision.sh` when:

* Updating the OS
* Replacing SD cards
* Re-deploying at a new site
* Resetting a device for a new client

The script is **idempotent** and will not duplicate installs.

---

## 12. Relationship to Other Docs

* **Architectural role:**
  `hardware/raspberry-pi/notes/edge-gateway.md`
* **Platform runtime:**
  `infra/poc-stack/`
* **ESP32 devices:**
  `docs/hardware/esp32.md`
* **Technician install context:**
  This document

Each file answers a **different operational question**.

---

### ✅ Status

* Aligned with PoC
* Field-deployable
* Technician-friendly
* Ready for client pilots


## Raspberry Pi Edge Gateway – Provisioning Environment File

**Ironlink IoT Platform**

This document describes the variables used by the Raspberry Pi edge gateway provisioning process.

---

### How to use

1. Copy the example file:

   ```bash
   cp provision.env.example provision.env
   ```
2. Edit `provision.env` for the specific site or client.
3. Run provisioning:

   ```bash
   set -a && source provision.env && set +a
   ./provision.sh
   ```

**Important**

* This file is **safe to share as a template**
* Do **not** commit `provision.env` (real values) to git

---

## Device Identity

Defines how the Raspberry Pi identifies itself on the network.

```bash
# Hostname for the Raspberry Pi
# Use a clear, site-based naming convention
# Examples:
#   SITE-A-GW-01
#   CLIENTX-WELD-EDGE-01
IRONLINK_HOSTNAME=SITE-A-GW-01
```

**Change this when:**

* Deploying to a new site
* Reassigning hardware to a different client

---

## Time & Locale

Controls system time configuration.

```bash
# System timezone
# Common values:
#   Africa/Johannesburg
#   Africa/Lusaka
#   UTC
IRONLINK_TIMEZONE=Africa/Johannesburg
```

**Change this when:**

* Deploying outside South Africa
* Aligning timestamps with local operations

---

## Docker & Stack Control

Controls Docker installation and which Ironlink stack is started.

```bash
# Install Docker and Docker Compose
# 1 = yes (recommended)
# 0 = no (Docker already installed)
IRONLINK_INSTALL_DOCKER=1
```

```bash
# Automatically start the Ironlink stack after provisioning
# 1 = start stack
# 0 = provision only
IRONLINK_START_STACK=1
```

```bash
# Relative path (from repo root) to docker-compose.yml
# Examples:
#   infra/poc-stack
#   infra/prod-stack
IRONLINK_STACK_DIR=infra/poc-stack
```

**Typical changes:**

* Switch to `infra/prod-stack` for hardened deployments
* Set `IRONLINK_START_STACK=0` if provisioning only

---

## Network & Security

Controls basic firewall behaviour.

```bash
# Enable UFW firewall with basic rules
# Opens:
#   - SSH (22)
#   - Grafana (3000)
#   - InfluxDB (8086)
#   - MQTT (1883)
# 1 = enable
# 0 = disable (default for PoC)
IRONLINK_ENABLE_UFW=0
```

**Recommended:**

* `0` for PoC and lab environments
* `1` for client pilots or production trials

---

## Post-Provision Behaviour

Controls whether the device reboots automatically.

```bash
# Automatically reboot after provisioning
# Recommended if hostname or Docker was installed
# 1 = reboot
# 0 = do not reboot
IRONLINK_REBOOT=0
```

**Tip:**
Set this to `1` when provisioning unattended or remotely.

---

## Notes for Technicians

* Log out and log back in if Docker was newly installed
* Grafana access:

  ```
  http://<PI-IP>:3000
  ```
* MQTT broker:

  ```
  tcp://<PI-IP>:1883
  ```

---

### Recommended practice

* Commit `provision.env.example`
* Ignore `provision.env`
* Treat `provision.env` as **site-specific configuration**
* Keep all logic in `provision.sh`

This keeps deployments repeatable, auditable, and safe across multiple clients and environments.
