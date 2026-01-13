#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-queries-testing}"
CONTEXT="${KWOK_CONTEXT:-kwok-${CLUSTER_NAME}}"

echo "[kwok] Annotating nodes with metrics endpoint path..."
for node in $(kubectl --context "${CONTEXT}" get nodes -o jsonpath='{.items[*].metadata.name}'); do
  kubectl --context "${CONTEXT}" annotate node "$node" \
    "metrics.k8s.io/resource-metrics-path=/metrics/nodes/$node/metrics/resource" \
    --overwrite
done

