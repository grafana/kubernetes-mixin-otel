#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-queries-testing}"
CONTEXT="${KWOK_CONTEXT:-kwok-${CLUSTER_NAME}}"

echo "[kwok] Applying ClusterResourceUsage for simulated container metrics..."
kubectl --context "${CONTEXT}" apply -f "${SCRIPT_DIR}/kwok-config/kwok-resource-usage.yaml"

