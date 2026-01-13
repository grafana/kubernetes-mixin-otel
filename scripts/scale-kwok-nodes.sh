#!/bin/bash
set -euo pipefail

NODE_COUNT="${1:-50}"
CLUSTER_NAME="${CLUSTER_NAME:-queries-testing}"

echo "[kwok] Scaling to ${NODE_COUNT} nodes..."
kwokctl scale node --name "${CLUSTER_NAME}" --replicas "${NODE_COUNT}"

