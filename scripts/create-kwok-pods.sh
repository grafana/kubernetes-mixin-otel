#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

POD_COUNT="${1:-200}"
POD_TEMPLATE="${SCRIPT_DIR}/kwok-config/kwok-pod-template.yaml"
CLUSTER_NAME="${CLUSTER_NAME:-queries-testing}"
CONTEXT="${KWOK_CONTEXT:-kwok-${CLUSTER_NAME}}"

echo "[kwok] Creating ${POD_COUNT} pods with resource requests..."

if [[ ! -f "${POD_TEMPLATE}" ]]; then
  echo "ERROR: Pod template not found at ${POD_TEMPLATE}"
  exit 1
fi

EXISTING_PODS=$(kubectl --context "${CONTEXT}" get pods -n default -l app=kwok-test -o name | wc -l | tr -d ' ')
if [[ "${EXISTING_PODS}" -ge "${POD_COUNT}" ]]; then
  echo "[kwok] Pods already exist (${EXISTING_PODS})"
  exit 0
fi

# Get list of existing pod names for quick lookup
EXISTING_POD_NAMES=$(kubectl --context "${CONTEXT}" get pods -n default -l app=kwok-test -o jsonpath='{.items[*].metadata.name}')

CREATED=0
for i in $(seq -f "%06g" 0 $((POD_COUNT - 1))); do
  POD_NAME="kwok-test-$i"
  if [[ ! " ${EXISTING_POD_NAMES} " =~ " ${POD_NAME} " ]]; then
    sed "s/PLACEHOLDER/$i/" "${POD_TEMPLATE}" | kubectl --context "${CONTEXT}" create -f -
    ((CREATED++))
  fi
done

echo "[kwok] Created ${CREATED} new pods (total: ${POD_COUNT})"

