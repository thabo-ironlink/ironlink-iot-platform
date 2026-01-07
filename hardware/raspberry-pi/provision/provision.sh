#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Ironlink IoT Platform - Raspberry Pi Edge Gateway Provisioning
#
# What it does:
# - Updates OS packages
# - Installs required tools (git, curl, jq, mosquitto-clients, etc.)
# - Installs Docker + Docker Compose plugin (Debian/Raspberry Pi OS)
# - Adds the current user to the docker group
# - Optionally starts the PoC stack from infra/poc-stack/docker-compose.yml
#
# How to run:
#   chmod +x hardware/raspberry-pi/provision/provision.sh
#   ./hardware/raspberry-pi/provision/provision.sh
#
# Optional environment variables (change these to fit your goals):
#   IRONLINK_HOSTNAME=iot-pi             # sets hostname (default: iot-pi)
#   IRONLINK_START_STACK=1               # 1 to start docker compose (default: 1)
#   IRONLINK_STACK_DIR=infra/poc-stack   # where docker-compose.yml lives
#   IRONLINK_INSTALL_DOCKER=1            # 1 to install docker (default: 1)
#   IRONLINK_ENABLE_UFW=0                # 1 to enable UFW with basic rules (default: 0)
#   IRONLINK_TIMEZONE=Africa/Johannesburg# timezone (default: Africa/Johannesburg)
#   IRONLINK_REBOOT=0                    # 1 to reboot after provisioning (default: 0)
#
# Notes:
# - Run as a normal user with sudo privileges (recommended).
# - After adding user to docker group, you must re-login for it to take effect.
# ==============================================================================

IRONLINK_HOSTNAME="${IRONLINK_HOSTNAME:-}"
IRONLINK_START_STACK="${IRONLINK_START_STACK:-1}"
IRONLINK_STACK_DIR="${IRONLINK_STACK_DIR:-infra/poc-stack}"
IRONLINK_INSTALL_DOCKER="${IRONLINK_INSTALL_DOCKER:-1}"
IRONLINK_ENABLE_UFW="${IRONLINK_ENABLE_UFW:-0}"
IRONLINK_TIMEZONE="${IRONLINK_TIMEZONE:-Africa/Johannesburg}"
IRONLINK_REBOOT="${IRONLINK_REBOOT:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# repo root = two levels up from hardware/raspberry-pi/provision/
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

log() { echo -e "\n[IRONLINK] $*\n"; }
warn() { echo -e "\n[IRONLINK][WARN] $*\n" >&2; }
die() { echo -e "\n[IRONLINK][ERROR] $*\n" >&2; exit 1; }

# Docker helpers: use docker without sudo if permitted, otherwise fallback to sudo
dkr() {
  if docker ps >/dev/null 2>&1; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

dc() {
  # Prefer plugin "docker compose", fallback to legacy "docker-compose"
  if docker compose version >/dev/null 2>&1; then
    dkr compose "$@"
  else
    dkr-compose "$@"
  fi
}

dkr-compose() {
  # docker-compose as a standalone binary (older distros)
  if docker-compose version >/dev/null 2>&1; then
    if docker ps >/dev/null 2>&1; then
      docker-compose "$@"
    else
      sudo docker-compose "$@"
    fi
  else
    die "docker-compose not found (install docker compose plugin or docker-compose)"
  fi
}


# ------------------------------------------------------------------------------
# v0.2.0+ Fleet Identity (required for 10–100 site operability)
# ------------------------------------------------------------------------------

IRONLINK_CLIENT_ID="${IRONLINK_CLIENT_ID:-}"
IRONLINK_SITE_ID="${IRONLINK_SITE_ID:-}"
IRONLINK_GATEWAY_ID="${IRONLINK_GATEWAY_ID:-}"
IRONLINK_ENVIRONMENT="${IRONLINK_ENVIRONMENT:-prod}"

# ------------------------------------------------------------------------------
# Stack runtime secrets (.env in infra/poc-stack)
# ------------------------------------------------------------------------------
INFLUXDB_DB="${INFLUXDB_DB:-ironlink_telemetry}"
INFLUXDB_PLATFORM_DB="${INFLUXDB_PLATFORM_DB:-ironlink_platform}"
INFLUXDB_RETENTION_DURATION="${INFLUXDB_RETENTION_DURATION:-90d}"
INFLUXDB_PLATFORM_RETENTION_DURATION="${INFLUXDB_PLATFORM_RETENTION_DURATION:-30d}"

INFLUXDB_ADMIN_USER="${INFLUXDB_ADMIN_USER:-ironadmin}"
INFLUXDB_ADMIN_PASSWORD="${INFLUXDB_ADMIN_PASSWORD:-}"

INFLUXDB_TELEGRAF_USER="${INFLUXDB_TELEGRAF_USER:-telegraf_writer}"
INFLUXDB_TELEGRAF_PASSWORD="${INFLUXDB_TELEGRAF_PASSWORD:-}"

GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-}"

MQTT_USERNAME="${MQTT_USERNAME:-mqtt_client}"
MQTT_PASSWORD="${MQTT_PASSWORD:-}"

# Compose project name (stable network/volume naming)
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ironlink}"


require_var() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "${value}" ]]; then
    die "Missing required variable: ${name}. Set it in provision.env (v0.2.0+)."
  fi
}

derive_hostname_if_missing() {
  # Keep PoC backwards compatibility:
  # - If IRONLINK_HOSTNAME is set, respect it.
  # - If not, and v0.2 identity is present, derive stable hostname.
  if [[ -z "${IRONLINK_HOSTNAME:-}" ]]; then
    if [[ -n "${IRONLINK_SITE_ID}" && -n "${IRONLINK_GATEWAY_ID}" ]]; then
      IRONLINK_HOSTNAME="${IRONLINK_SITE_ID}-${IRONLINK_GATEWAY_ID}"
    else
      IRONLINK_HOSTNAME="iot-pi"
    fi
  fi
}

enforce_identity_if_prod() {
  # In production mode, enforce identity tuple strictly.
  # Change the condition here if you want enforcement in all envs.
  if [[ "${IRONLINK_ENVIRONMENT}" == "prod" ]]; then
    require_var IRONLINK_CLIENT_ID
    require_var IRONLINK_SITE_ID
    require_var IRONLINK_GATEWAY_ID
  fi
}


require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    die "sudo not found. Install sudo or run as root (not recommended)."
  fi
  if ! sudo -n true >/dev/null 2>&1; then
    log "sudo password may be required..."
  fi
}

is_pi() {
  # best-effort check
  grep -qiE "raspberry pi|bcm27|bcm28|raspi" /proc/device-tree/model 2>/dev/null || true
}

set_timezone() {
  if command -v timedatectl >/dev/null 2>&1; then
    log "Setting timezone: ${IRONLINK_TIMEZONE}"
    sudo timedatectl set-timezone "${IRONLINK_TIMEZONE}" || warn "Could not set timezone via timedatectl."
  else
    warn "timedatectl not available; skipping timezone set."
  fi
}

set_hostname() {
  local current
  current="$(hostname)"
  if [[ "${current}" == "${IRONLINK_HOSTNAME}" ]]; then
    log "Hostname already set to '${IRONLINK_HOSTNAME}'."
    return
  fi

  log "Setting hostname to '${IRONLINK_HOSTNAME}' (current: '${current}')"
  sudo hostnamectl set-hostname "${IRONLINK_HOSTNAME}"

  # Ensure /etc/hosts has a 127.0.1.1 mapping
  if grep -qE '^127\.0\.1\.1' /etc/hosts; then
    sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${IRONLINK_HOSTNAME}/" /etc/hosts
  else
    echo -e "127.0.1.1\t${IRONLINK_HOSTNAME}" | sudo tee -a /etc/hosts >/dev/null
  fi

  log "Hostname updated. A reboot is recommended for all services to reflect the change."
}

apt_update_upgrade() {
  log "Updating package lists and upgrading base packages..."
  sudo apt-get update -y
  sudo apt-get upgrade -y
}

install_base_packages() {
  log "Installing base packages..."
  sudo apt-get install -y \
    ca-certificates \
    curl \
    git \
    jq \
    nano \
    unzip \
    wget \
    mosquitto-clients \
    net-tools \
    iproute2
}

install_docker() {
  if [[ "${IRONLINK_INSTALL_DOCKER}" != "1" ]]; then
    warn "Skipping Docker installation (IRONLINK_INSTALL_DOCKER=${IRONLINK_INSTALL_DOCKER})."
    return
  fi

  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version || true)"
  else
    log "Installing Docker (from Debian/RPi OS repos)..."
    # Using distro packages for Raspberry Pi OS stability
    sudo apt-get install -y docker.io docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
  fi

  # Add current user to docker group
  local user
  user="$(id -un)"
  if groups "${user}" | grep -q '\bdocker\b'; then
    log "User '${user}' already in docker group."
  else
    log "Adding user '${user}' to docker group (you must re-login for this to apply)."
    sudo usermod -aG docker "${user}"
  fi

  log "Docker info:"
  docker --version || true
  docker compose version || true
}

enable_ufw() {
  if [[ "${IRONLINK_ENABLE_UFW}" != "1" ]]; then
    log "UFW not enabled (IRONLINK_ENABLE_UFW=${IRONLINK_ENABLE_UFW})."
    return
  fi

  log "Installing and enabling UFW with basic rules..."
  sudo apt-get install -y ufw

  # Allow SSH (important for headless)
  sudo ufw allow 22/tcp

  # Defense-in-depth: block these even though we bind to 127.0.0.1 in docker-compose
  sudo ufw deny 3000/tcp
  sudo ufw deny 8086/tcp

  # Allow MQTT from LAN ranges (adjust if your LAN differs)
  sudo ufw allow from 192.168.0.0/16 to any port 1883 proto tcp

  sudo ufw --force enable
  sudo ufw status verbose || true
}

validate_repo_paths() {
  log "Validating repo root and stack path..."
  [[ -d "${REPO_ROOT}" ]] || die "Repo root not found: ${REPO_ROOT}"

  local stack_abs="${REPO_ROOT}/${IRONLINK_STACK_DIR}"
  [[ -d "${stack_abs}" ]] || die "Stack directory not found: ${stack_abs}"
  [[ -f "${stack_abs}/docker-compose.yml" ]] || die "docker-compose.yml not found in: ${stack_abs}"

  log "Repo root: ${REPO_ROOT}"
  log "Stack dir : ${stack_abs}"
}

disable_conflicting_services() {
  log "Disabling conflicting host services (mosquitto, influxdb, grafana-server) to avoid port conflicts..."
  sudo systemctl stop mosquitto influxdb grafana-server 2>/dev/null || true
  sudo systemctl disable mosquitto influxdb grafana-server 2>/dev/null || true
}


rand_b64() {
  # 32 bytes base64 (~43 chars). Good enough for PoC secrets.
  openssl rand -base64 32
}

stack_dir_abs() {
  echo "${REPO_ROOT}/${IRONLINK_STACK_DIR}"
}

ensure_stack_env_file() {
  local stack_abs
  stack_abs="$(stack_dir_abs)"
  local env_file="${stack_abs}/.env"

  if [[ -f "${env_file}" ]]; then
    log "Stack .env already exists: ${env_file}"
    return 0
  fi

  log "Creating stack runtime .env: ${env_file}"

  # generate passwords if not provided
  INFLUXDB_ADMIN_PASSWORD="${INFLUXDB_ADMIN_PASSWORD}"
  INFLUXDB_TELEGRAF_PASSWORD="${INFLUXDB_TELEGRAF_PASSWORD}"
  GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD}"
  MQTT_PASSWORD="${MQTT_PASSWORD}"


  cat > "${env_file}" <<EOF
# ==============================================================================
# Ironlink PoC Stack Runtime Secrets (DO NOT COMMIT)
# Location: infra/poc-stack/.env
# ==============================================================================

# Fleet identity (used by Telegraf tags)
IRONLINK_CLIENT_ID=${IRONLINK_CLIENT_ID}
IRONLINK_SITE_ID=${IRONLINK_SITE_ID}
IRONLINK_GATEWAY_ID=${IRONLINK_GATEWAY_ID}
IRONLINK_ENVIRONMENT=${IRONLINK_ENVIRONMENT}
IRONLINK_HOSTNAME=${IRONLINK_HOSTNAME}

# InfluxDB
INFLUXDB_DB=${INFLUXDB_DB}
INFLUXDB_PLATFORM_DB=${INFLUXDB_PLATFORM_DB}
INFLUXDB_RETENTION_DURATION=${INFLUXDB_RETENTION_DURATION}
INFLUXDB_PLATFORM_RETENTION_DURATION=${INFLUXDB_PLATFORM_RETENTION_DURATION}

INFLUXDB_ADMIN_USER=${INFLUXDB_ADMIN_USER}
INFLUXDB_ADMIN_PASSWORD=${INFLUXDB_ADMIN_PASSWORD}
INFLUXDB_TELEGRAF_USER=${INFLUXDB_TELEGRAF_USER}
INFLUXDB_TELEGRAF_PASSWORD=${INFLUXDB_TELEGRAF_PASSWORD}

# Grafana
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}

# MQTT auth
MQTT_USERNAME=${MQTT_USERNAME}
MQTT_PASSWORD=${MQTT_PASSWORD}

# InfluxDB auth toggle (provisioning uses this)
INFLUXDB_HTTP_AUTH_ENABLED=true
EOF

  chmod 600 "${env_file}"
  log "Created .env with chmod 600."
}

render_telegraf_config() {
  local stack_abs
  stack_abs="$(stack_dir_abs)"

  local tpl="${stack_abs}/telegraf/telegraf.conf.template"
  local out="${stack_abs}/telegraf/telegraf.conf"

  if [[ ! -f "${tpl}" ]]; then
    warn "Telegraf template not found: ${tpl} (skipping render)"
    return 0
  fi

  log "Rendering Telegraf config: ${out}"
  cd "${stack_abs}"

  # export vars from .env for envsubst
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a

  envsubst < "${tpl}" > "${out}"
  chmod 644 "${out}"

  # sanity: fail if unresolved placeholders remain
  if grep -q '\${' "${out}"; then
    die "Telegraf config render left unresolved placeholders. Check .env and template."
  fi
}

generate_mqtt_passwordfile() {
  local stack_abs
  stack_abs="$(stack_dir_abs)"
  local pwfile="${stack_abs}/mosquitto/passwordfile"

  if [[ ! -d "${stack_abs}/mosquitto" ]]; then
    die "Mosquitto directory not found: ${stack_abs}/mosquitto"
  fi

  log "Generating/updating MQTT passwordfile (non-interactive): ${pwfile}"

  cd "${stack_abs}"
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a

  if [[ -f "${pwfile}" ]]; then
    # update existing
    echo "${MQTT_PASSWORD}" | dkr run --rm -i \
      -v "${stack_abs}/mosquitto:/mosquitto/config" \
      eclipse-mosquitto:2.0.18 \
      mosquitto_passwd -b /mosquitto/config/passwordfile "${MQTT_USERNAME}" -
  else
    # create new
    echo "${MQTT_PASSWORD}" | dkr run --rm -i \
      -v "${stack_abs}/mosquitto:/mosquitto/config" \
      eclipse-mosquitto:2.0.18 \
      mosquitto_passwd -c -b /mosquitto/config/passwordfile "${MQTT_USERNAME}" -
  fi

  chmod 600 "${pwfile}"
}

initialize_influxdb_once() {
  local stack_abs
  stack_abs="$(stack_dir_abs)"
  local sentinel="${stack_abs}/.influx_initialized"

  if [[ -f "${sentinel}" ]]; then
    log "InfluxDB already initialized (sentinel exists)."
    return 0
  fi

  # if data dir already populated, assume initialized
  if [[ -d "${stack_abs}/influxdb-data" ]] && [[ -n "$(ls -A "${stack_abs}/influxdb-data" 2>/dev/null || true)" ]]; then
    log "InfluxDB data dir is not empty. Assuming initialized; creating sentinel."
    touch "${sentinel}"
    return 0
  fi

  log "Initializing InfluxDB (first boot): auth OFF during init, then ON for steady state."

  cd "${stack_abs}"
  export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ironlink}"

  # start influxdb with auth disabled
  INFLUXDB_HTTP_AUTH_ENABLED=false dc up -d influxdb

  # wait for readiness using influx CLI inside container
  local max_wait=90
  local waited=0
  until dc exec -T influxdb influx -execute "SHOW DATABASES" >/dev/null 2>&1; do
    sleep 2
    waited=$((waited + 2))
    if [[ "${waited}" -ge "${max_wait}" ]]; then
      die "InfluxDB did not become ready within ${max_wait}s"
    fi
  done

  # run init container (joins correct network automatically)
  log "Running influxdb-init one-shot container..."
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a

  COMPOSE_PROFILES=init dc run --rm influxdb-init

  # stop influxdb so it restarts later with auth enabled
  dc stop influxdb

  # bring influxdb back up with auth enabled (steady state)
  log "Starting InfluxDB with auth enabled (steady state)..."
  INFLUXDB_HTTP_AUTH_ENABLED=true dc up -d influxdb

  touch "${sentinel}"
  log "InfluxDB initialization complete. Sentinel created: ${sentinel}"

}


start_stack() {
  if [[ "${IRONLINK_START_STACK}" != "1" ]]; then
    warn "Skipping stack startup (IRONLINK_START_STACK=${IRONLINK_START_STACK})."
    return
  fi

  validate_repo_paths

  local stack_abs="${REPO_ROOT}/${IRONLINK_STACK_DIR}"
  log "Starting PoC stack from: ${stack_abs}"

  export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ironlink}"

  cd "${stack_abs}"

  dc pull
  dc up -d

  log "Stack started. Current containers:"
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true

  log "Local endpoints:"
  echo "  - Grafana : http://127.0.0.1:3000 (bound localhost; use SSH tunnel)"
  echo "  - InfluxDB: http://127.0.0.1:8086 (bound localhost; use SSH tunnel)"
  echo "  - MQTT    : tcp://$(hostname -I | awk '{print $1}'):1883"
}


post_checks() {
  log "Post-checks (best effort)..."

  if command -v docker >/dev/null 2>&1; then
    sudo systemctl is-active docker >/dev/null 2>&1 && echo "Docker: active" || echo "Docker: not active"
  fi

  # Quick MQTT broker connectivity test (only meaningful if mosquitto is running)
  if command -v mosquitto_pub >/dev/null 2>&1; then
    echo "MQTT tools: installed"
  fi

  echo "Hostname: $(hostname)"
  echo "IP(s)   : $(hostname -I || true)"
}

main() {
  require_sudo

  if is_pi; then
    log "Detected Raspberry Pi hardware."
  else
    warn "Could not confidently detect Raspberry Pi. Continuing anyway."
  fi

  derive_hostname_if_missing
  enforce_identity_if_prod

  log "Identity:"
  echo "  ENV       : ${IRONLINK_ENVIRONMENT}"
  echo "  CLIENT_ID : ${IRONLINK_CLIENT_ID:-<unset>}"
  echo "  SITE_ID   : ${IRONLINK_SITE_ID:-<unset>}"
  echo "  GATEWAY_ID: ${IRONLINK_GATEWAY_ID:-<unset>}"
  echo "  HOSTNAME  : ${IRONLINK_HOSTNAME}"


  set_timezone
  set_hostname

  apt_update_upgrade
  install_base_packages
  install_docker
  enable_ufw
  disable_conflicting_services
  ensure_stack_env_file
  render_telegraf_config
  generate_mqtt_passwordfile
  initialize_influxdb_once
  start_stack
  post_checks

  if [[ "${IRONLINK_REBOOT}" == "1" ]]; then
    log "Reboot requested (IRONLINK_REBOOT=1). Rebooting now..."
    sudo reboot
  else
    log "Provisioning complete."
    echo "IMPORTANT: If docker group was newly added, log out and back in to use docker without sudo."
  fi
}

main "$@"
