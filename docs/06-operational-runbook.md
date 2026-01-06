# Operational Runbook (PoC)

## Check service status
```bash
docker-compose ps
docker ps
```
## Check Mosquitto logs

Mosquitto logs are written to a file inside the container:
```bash
docker exec -it mosquitto sh -lc "tail -n 80 /mosquitto/log/mosquitto.log"
```

## Test publish
```bash
docker exec -it mosquitto mosquitto_pub -h localhost \
  -t "ironlink/env/HOME/esp32/dht11" \
  -m '{"temp_c": 26.1, "humidity": 55}'
```

## Verify ingestion in InfluxDB
```bash
docker exec -it influxdb influx -username ironadmin -password <pass> \
  -database telemetry \
  -execute "SELECT * FROM mqtt_consumer ORDER BY time DESC LIMIT 5"
```