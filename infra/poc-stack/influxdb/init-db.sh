#!/bin/bash
set -euo pipefail

INFLUX_HOST="${INFLUX_HOST:-influxdb}"
INFLUX_PORT="${INFLUX_PORT:-8086}"

influx_noauth() {
  influx -host "${INFLUX_HOST}" -port "${INFLUX_PORT}" "$@"
}

influx_admin() {
  influx -host "${INFLUX_HOST}" -port "${INFLUX_PORT}" \
    -username "${INFLUXDB_ADMIN_USER}" -password "${INFLUXDB_ADMIN_PASSWORD}" "$@"
}

# ------------------------------------------------------------------------------
# Wait for InfluxDB (safe because provisioning runs init with auth disabled)
# ------------------------------------------------------------------------------
max_wait=90
waited=0
until influx_noauth -execute "SHOW DATABASES" >/dev/null 2>&1; do
  echo "Waiting for InfluxDB to be ready at ${INFLUX_HOST}:${INFLUX_PORT}..."
  sleep 2
  waited=$((waited + 2))
  if [[ "${waited}" -ge "${max_wait}" ]]; then
    echo "ERROR: InfluxDB not ready after ${max_wait}s" >&2
    exit 1
  fi
done

sleep 2

# ------------------------------------------------------------------------------
# Create DBs (idempotent)
# ------------------------------------------------------------------------------
influx_noauth -execute "CREATE DATABASE \"${INFLUXDB_DB}\"" || true
influx_noauth -execute "CREATE DATABASE \"${INFLUXDB_PLATFORM_DB}\"" || true

# ------------------------------------------------------------------------------
# Users (idempotent-ish; CREATE will fail if exists, which is fine)
# ------------------------------------------------------------------------------
influx_noauth -execute "CREATE USER \"${INFLUXDB_ADMIN_USER}\" WITH PASSWORD '${INFLUXDB_ADMIN_PASSWORD}' WITH ALL PRIVILEGES" || true
influx_noauth -execute "CREATE USER \"${INFLUXDB_TELEGRAF_USER}\" WITH PASSWORD '${INFLUXDB_TELEGRAF_PASSWORD}'" || true

# ------------------------------------------------------------------------------
# Grants
# ------------------------------------------------------------------------------
# Admin full access on both DBs
influx_admin -execute "GRANT ALL ON \"${INFLUXDB_DB}\" TO \"${INFLUXDB_ADMIN_USER}\"" || true
influx_admin -execute "GRANT ALL ON \"${INFLUXDB_PLATFORM_DB}\" TO \"${INFLUXDB_ADMIN_USER}\"" || true

# Telegraf writer access on both DBs (since you're writing to both)
influx_admin -execute "GRANT WRITE ON \"${INFLUXDB_DB}\" TO \"${INFLUXDB_TELEGRAF_USER}\"" || true
influx_admin -execute "GRANT WRITE ON \"${INFLUXDB_PLATFORM_DB}\" TO \"${INFLUXDB_TELEGRAF_USER}\"" || true

# ------------------------------------------------------------------------------
# Retention policies (stable names, proper idempotency)
# ------------------------------------------------------------------------------
TELEMETRY_RP="default_telemetry"
PLATFORM_RP="default_platform"

TELEMETRY_DUR="${INFLUXDB_RETENTION_DURATION:-90d}"
PLATFORM_DUR="${INFLUXDB_PLATFORM_RETENTION_DURATION:-30d}"

# Telemetry RP
if ! influx_admin -execute "SHOW RETENTION POLICIES ON \"${INFLUXDB_DB}\"" | awk '{print $1}' | grep -qx "${TELEMETRY_RP}"; then
  echo "Creating telemetry retention policy ${TELEMETRY_RP} (${TELEMETRY_DUR})..."
  influx_admin -execute "CREATE RETENTION POLICY \"${TELEMETRY_RP}\" ON \"${INFLUXDB_DB}\" DURATION ${TELEMETRY_DUR} REPLICATION 1 DEFAULT"
else
  echo "Telemetry retention policy ${TELEMETRY_RP} already exists"
fi

# Platform RP
if ! influx_admin -execute "SHOW RETENTION POLICIES ON \"${INFLUXDB_PLATFORM_DB}\"" | awk '{print $1}' | grep -qx "${PLATFORM_RP}"; then
  echo "Creating platform retention policy ${PLATFORM_RP} (${PLATFORM_DUR})..."
  influx_admin -execute "CREATE RETENTION POLICY \"${PLATFORM_RP}\" ON \"${INFLUXDB_PLATFORM_DB}\" DURATION ${PLATFORM_DUR} REPLICATION 1 DEFAULT"
else
  echo "Platform retention policy ${PLATFORM_RP} already exists"
fi

echo "InfluxDB init complete."
