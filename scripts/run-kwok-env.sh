#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-queries-testing}"
KWOK_CONTEXT="kwok-${CLUSTER_NAME}"
KWOK_NET="kwok-${CLUSTER_NAME}"
OTEL_CONFIG="${SCRIPT_DIR}/kwok-config/kwok-otel-collector.yaml"
KUBECONFIG_TEMPLATE="${SCRIPT_DIR}/kwok-config/otel-kwokconfig.yaml"
KUBECONFIG_OUT="/tmp/kwok-kubeconfig"

# Configurable node and pod counts (defaults: 1 node, 0 batch pods for parity with dev)
NODE_COUNT="${NODE_COUNT:-1}"
POD_COUNT="${POD_COUNT:-0}"

echo "=== KWOK + LGTM + OTel bootstrap for ${CLUSTER_NAME} ==="

# 1. Ensure KWOK cluster exists
if ! kwokctl get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "[kwok] Creating cluster ${CLUSTER_NAME}..."
  kwokctl create cluster --name "${CLUSTER_NAME}" --enable-crds ClusterResourceUsage,ResourceUsage
else
  echo "[kwok] Cluster ${CLUSTER_NAME} already exists."
fi

# 2. Switch kubectl context
echo "[kubectl] Using context ${KWOK_CONTEXT}..."
kubectl config use-context "${KWOK_CONTEXT}"

# 3. Setup KWOK nodes, pods, resource usage, and annotations
make -C "${SCRIPT_DIR}/.." kwok-setup NODE_COUNT="${NODE_COUNT}" POD_COUNT="${POD_COUNT}" KWOK_DEFAULT_NAMESPACE_PODS="${KWOK_DEFAULT_NAMESPACE_PODS:-}"

# 4. Generate kubeconfig for Docker from template
  # KWOK stores TLS certs in this directory. Needed to connect to the KWOK API server
echo "[kubeconfig] Generating ${KUBECONFIG_OUT}..."
PKI_DIR="$HOME/.kwok/clusters/${CLUSTER_NAME}/pki"
if [[ ! -d "${PKI_DIR}" ]]; then
  echo "ERROR: PKI dir ${PKI_DIR} not found. Is the KWOK cluster healthy?"
  exit 1
fi

# Read server URL for this context and rewrite hostname for Docker
SERVER_URL="$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="'"${KWOK_CONTEXT}"'")].cluster.server}')"
if [[ -z "${SERVER_URL}" ]]; then
  echo "ERROR: Could not find server URL for context ${KWOK_CONTEXT}"
  exit 1
fi

KWOK_API_SERVER="${SERVER_URL/127.0.0.1/host.docker.internal}"
KWOK_API_SERVER="${KWOK_API_SERVER/localhost/host.docker.internal}"

# Base64 encode cert and key
CLIENT_CERT_DATA="$(base64 -w 0 -i "${PKI_DIR}/admin.crt")"
CLIENT_KEY_DATA="$(base64 -w 0 -i "${PKI_DIR}/admin.key")"


if [[ ! -f "${KUBECONFIG_TEMPLATE}" ]]; then
  echo "ERROR: kubeconfig template not found at ${KUBECONFIG_TEMPLATE}"
  exit 1
fi

sed -e "s|\${KWOK_CONTEXT}|${KWOK_CONTEXT}|g" \
    -e "s|\${KWOK_API_SERVER}|${KWOK_API_SERVER}|g" \
    -e "s|\${CLIENT_CERT_DATA}|${CLIENT_CERT_DATA}|g" \
    -e "s|\${CLIENT_KEY_DATA}|${CLIENT_KEY_DATA}|g" \
    "${KUBECONFIG_TEMPLATE}" > "${KUBECONFIG_OUT}"

echo "[kubeconfig] Wrote ${KUBECONFIG_OUT}:"
grep -E 'server:|insecure-skip-tls-verify' "${KUBECONFIG_OUT}"

# 5. Start local LGTM (grafana/otel-lgtm) if needed
if docker ps --format '{{.Names}}' | grep -q '^lgtm$'; then
  echo "[lgtm] Container 'lgtm' already running."
else
  if docker ps -a --format '{{.Names}}' | grep -q '^lgtm$'; then
    echo "[lgtm] Removing stopped 'lgtm' container..."
    docker rm -f lgtm
  fi
  echo "[lgtm] Starting grafana/otel-lgtm container..."
  docker run -d \
    --name lgtm \
    --network "${KWOK_NET}" \
    -p 3001:3000 \
    -p 4317:4317 \
    -p 4318:4318 \
    -p 9090:9090 \
    -v "${SCRIPT_DIR}/provisioning/dashboards/dashboards.yaml:/otel-lgtm/grafana/conf/provisioning/dashboards/dashboards.yaml" \
    -v "${SCRIPT_DIR}/../dashboards_out:/kubernetes-mixin-otel/dashboards_out" \
    grafana/otel-lgtm:latest
fi

# 6. Build and start kwok-stats-proxy (provides /stats/summary for kubeletstatsreceiver)
source "${SCRIPT_DIR}/run-kwok-stats-proxy.sh"

# 7. Start OTel collector container
if docker ps --format '{{.Names}}' | grep -q '^kwok-otel-collector$'; then
  echo "[otel] Removing existing kwok-otel-collector container..."
  docker rm -f kwok-otel-collector
elif docker ps -a --format '{{.Names}}' | grep -q '^kwok-otel-collector$'; then
  echo "[otel] Removing stopped kwok-otel-collector container..."
  docker rm -f kwok-otel-collector
fi
echo "[otel] Starting main otel/opentelemetry-collector-contrib (kwok-otel-collector)..."
docker run -d \
  --name kwok-otel-collector \
  --network "${KWOK_NET}" \
  --add-host=host.docker.internal:host-gateway \
  -v "${KUBECONFIG_OUT}:/kube/config" \
  -e KUBECONFIG=/kube/config \
  -e CLUSTER_NAME="${CLUSTER_NAME}" \
  -e K8S_NODE_NAME="${CLUSTER_NAME}" \
  -e STATS_PROXY_ENDPOINT="http://host.docker.internal:10250" \
  -p 8889:8889 \
  -v "${OTEL_CONFIG}:/etc/otelcol/config.yaml" \
  otel/opentelemetry-collector-contrib:latest \
  --config /etc/otelcol/config.yaml

# 8. Start hostmetrics faker (single lightweight container replaces N replicator containers).
#     Generates fake hostmetrics OTLP data for all nodes (except the first, which the main
#     collector already handles) and POSTs it to LGTM.
HOSTMETRICS_FAKER_DIR="${SCRIPT_DIR}/kwok-hostmetrics-faker"
for c in $(docker ps -a -q --filter "name=kwok-hostmetrics" 2>/dev/null); do
  docker rm -f "$c" 2>/dev/null || true
done
NODES=$(kubectl --context "${KWOK_CONTEXT}" get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
FIRST_NODE=""
FAKER_NODES=""
for NODE in ${NODES}; do
  # Skip first node (main collector already reports hostmetrics for it)
  if [[ -z "${FIRST_NODE}" ]]; then
    FIRST_NODE="${NODE}"
    continue
  fi
  if [[ -n "${FAKER_NODES}" ]]; then
    FAKER_NODES="${FAKER_NODES},"
  fi
  FAKER_NODES="${FAKER_NODES}${NODE}"
done

if [[ -n "${FAKER_NODES}" ]]; then
  echo "[hostmetrics] Building kwok-hostmetrics-faker image..."
  docker build -t kwok-hostmetrics-faker:latest "${HOSTMETRICS_FAKER_DIR}"
  echo "[hostmetrics] Starting faker for nodes: ${FAKER_NODES}"
  docker run -d \
    --name kwok-hostmetrics-faker \
    --network "${KWOK_NET}" \
    -e NODE_NAMES="${FAKER_NODES}" \
    -e CLUSTER_NAME="${CLUSTER_NAME}" \
    -e GATEWAY_ENDPOINT="http://lgtm:4318" \
    kwok-hostmetrics-faker:latest
else
  echo "[hostmetrics] Single node only; main collector handles hostmetrics."
fi

# 9. Start Beyla for auto-instrumentation tracing (optional)
if [[ "${ENABLE_BEYLA:-false}" == "true" ]]; then
  make -C "${SCRIPT_DIR}/.." kwok-beyla
fi

echo
echo "=== Done ==="
echo "KWOK cluster:           ${CLUSTER_NAME} (context: ${KWOK_CONTEXT})"
echo "Kubeconfig for Docker:  ${KUBECONFIG_OUT}"
echo "LGTM (Grafana):         http://localhost:3001"
echo "Collector Prometheus:   http://localhost:8889/metrics"
if [[ "${ENABLE_BEYLA:-false}" == "true" ]]; then
  echo "Beyla tracing:          Enabled (traces → Grafana Tempo)"
fi
echo
echo "Useful checks:"
echo "  kubectl --context ${KWOK_CONTEXT} get nodes | wc -l"
echo "  kubectl --context ${KWOK_CONTEXT} get pods -A | head"
echo "  curl -s http://localhost:8889/metrics | head"
