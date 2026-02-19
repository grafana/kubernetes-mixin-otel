#!/bin/bash
# Starts Beyla for tracing Grafana dashboard query performance (Grafana → Prometheus/Mimir)
#
# Usage: make kwok-beyla (after LGTM container is running)

set -euo pipefail

# Stop gracefully first, then force remove (avoids zombie with --pid=host)
if docker ps -a --format '{{.Names}}' | grep -q '^kwok-beyla$'; then
  echo "[beyla] Stopping kwok-beyla container..."
  docker stop kwok-beyla --timeout 5 || true
  docker rm -f kwok-beyla || true
fi

LGTM_IP=$(docker inspect lgtm --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
if [[ -z "${LGTM_IP}" ]]; then
  echo "ERROR: Could not get LGTM container IP. Is the lgtm container running?"
  exit 1
fi

echo "[beyla] LGTM container IP: ${LGTM_IP}"
echo "[beyla] Starting Grafana Beyla for query performance tracing..."
docker run -d \
  --name kwok-beyla \
  --init \
  --privileged \
  --pid=host \
  --network=host \
  -e BEYLA_OPEN_PORT=3000,9090 \
  -e BEYLA_TRACE_PRINTER=text \
  -e BEYLA_SERVICE_NAME=grafana-lgtm \
  -e BEYLA_TRACES_EXPORTER=otlp \
  -e OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
  -e OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318" \
  grafana/beyla:latest

echo "[beyla] Beyla tracing enabled - query traces will appear in Grafana Tempo"

