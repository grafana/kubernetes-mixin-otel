#!/bin/bash
# Build and start kwok-stats-proxy (provides /stats/summary for kubeletstatsreceiver)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KUBECONFIG_OUT="${KUBECONFIG_OUT:-/tmp/kwok-kubeconfig}"
KUBECONFIG_DOCKER="/tmp/kwok-kubeconfig-docker"
STATS_PROXY_DIR="${SCRIPT_DIR}/kwok-stats-proxy"
STATS_PROXY_IMAGE="kwok-stats-proxy:latest"

# Remove existing container if any
make -C "${SCRIPT_DIR}/.." kwok-stats-proxy-rm

echo "[stats-proxy] Building kwok-stats-proxy image..."
docker build -t "${STATS_PROXY_IMAGE}" "${STATS_PROXY_DIR}"

# Create a Docker-compatible kubeconfig (replace 127.0.0.1 with host.docker.internal)
echo "[stats-proxy] Creating Docker-compatible kubeconfig..."
sed 's/127\.0\.0\.1/host.docker.internal/g' "${KUBECONFIG_OUT}" > "${KUBECONFIG_DOCKER}"

echo "[stats-proxy] Starting kwok-stats-proxy container..."
docker run -d \
  --name kwok-stats-proxy \
  -v "${KUBECONFIG_DOCKER}:/kube/config" \
  -e KUBECONFIG=/kube/config \
  -p 10250:10250 \
  "${STATS_PROXY_IMAGE}"

# Get stats proxy IP for OTel collector
STATS_PROXY_IP=$(docker inspect kwok-stats-proxy --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
if [[ -z "${STATS_PROXY_IP}" ]]; then
  echo "ERROR: Could not get stats proxy IP. Is the container running?"
  exit 1
fi
echo "[stats-proxy] Stats proxy IP: ${STATS_PROXY_IP}"

# Export for use by calling script
export STATS_PROXY_IP

