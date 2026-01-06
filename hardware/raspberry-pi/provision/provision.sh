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

# ------------------------------------------------------------------------------
# v0.2.0+ Fleet Identity (required for 10–100 site operability)
# ------------------------------------------------------------------------------

IRONLINK_CLIENT_ID="${IRONLINK_CLIENT_ID:-}"
IRONLINK_SITE_ID="${IRONLINK_SITE_ID:-}"
IRONLINK_GATEWAY_ID="${IRONLINK_GATEWAY_ID:-}"
IRONLINK_ENVIRONMENT="${IRONLINK_ENVIRONMENT:-prod}"

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

  # Allow Grafana (local access)
  sudo ufw allow 3000/tcp

  # Allow InfluxDB (local access / debugging)
  sudo ufw allow 8086/tcp

  # Allow MQTT (local LAN devices publish to broker)
  sudo ufw allow 1883/tcp

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


start_stack() {
  if [[ "${IRONLINK_START_STACK}" != "1" ]]; then
    warn "Skipping stack startup (IRONLINK_START_STACK=${IRONLINK_START_STACK})."
    return
  fi

  validate_repo_paths

  local stack_abs="${REPO_ROOT}/${IRONLINK_STACK_DIR}"
  log "Starting PoC stack from: ${stack_abs}"

  # Pull images first (helps on slow networks)
  (cd "${stack_abs}" && sudo docker-compose pull)

  # Bring stack up
  (cd "${stack_abs}" && sudo docker-compose up -d)

  log "Stack started. Current containers:"
  sudo docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true

  log "Local endpoints (adjust if you changed ports in docker-compose.yml):"
  echo "  - Grafana : http://$(hostname -I | awk '{print $1}'):3000"
  echo "  - InfluxDB: http://$(hostname -I | awk '{print $1}'):8086"
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
