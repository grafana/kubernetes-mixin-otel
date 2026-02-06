#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

POD_COUNT="${1:-200}"
POD_TEMPLATE="${SCRIPT_DIR}/kwok-config/kwok-pod-template.yaml"
CLUSTER_NAME="${CLUSTER_NAME:-queries-testing}"
CONTEXT="${KWOK_CONTEXT:-kwok-${CLUSTER_NAME}}"

# Default: split pods across default and kube-system (half each). Override with KWOK_DEFAULT_NAMESPACE_PODS.
DEFAULT_NAMESPACE_PODS="${KWOK_DEFAULT_NAMESPACE_PODS:-$((POD_COUNT / 2))}"

echo "[kwok] Creating ${POD_COUNT} pods with resource requests (default: ${DEFAULT_NAMESPACE_PODS}, kube-system: $((POD_COUNT - DEFAULT_NAMESPACE_PODS)))..."

ensure_namespace_sa() {
  local ns="$1"
  if ! kubectl --context "${CONTEXT}" get namespace "${ns}" 2>/dev/null; then
    echo "[kwok] Creating namespace ${ns}..."
    kubectl --context "${CONTEXT}" create namespace "${ns}"
  fi
  if ! kubectl --context "${CONTEXT}" get serviceaccount default -n "${ns}" 2>/dev/null; then
    echo "[kwok] Creating default service account in ${ns}..."
    kubectl --context "${CONTEXT}" create serviceaccount default -n "${ns}"
  fi
}

ensure_namespace_sa default
ensure_namespace_sa kube-system

if [[ ! -f "${POD_TEMPLATE}" ]]; then
  echo "ERROR: Pod template not found at ${POD_TEMPLATE}"
  exit 1
fi

BATCH_SIZE=50

create_batch() {
  local manifest="$1"
  local max_attempts=5
  local attempt=1
  local err
  while true; do
    err=$(echo "${manifest}" | kubectl --context "${CONTEXT}" create -f - 2>&1) && return 0
    if [[ ${attempt} -ge ${max_attempts} ]]; then
      echo "[kwok] ERROR: Failed after ${max_attempts} attempts: ${err}" >&2
      return 1
    fi
    if [[ "${err}" =~ (connection lost|connection refused|EOF|http2:) ]]; then
      echo "[kwok] Attempt ${attempt}/${max_attempts} failed (connection issue), retrying in $((attempt * 2))s..." >&2
      sleep $((attempt * 2))
      ((attempt++))
    else
      echo "[kwok] ERROR: ${err}" >&2
      return 1
    fi
  done
}

pod_manifest() {
  local i="$1"
  local ns="$2"
  local manifest
  manifest=$(sed "s/PLACEHOLDER/$i/" "${POD_TEMPLATE}")
  if [[ "${ns}" != "default" ]]; then
    manifest=$(echo "${manifest}" | sed "s/namespace: default/namespace: ${ns}/")
  fi
  echo "${manifest}"
}

CREATED=0
BATCH_YAML=""
BATCH_COUNT=0
idx=0

for i in $(seq -f "%06g" 0 $((POD_COUNT - 1))); do
  if [[ -n "${DEFAULT_NAMESPACE_PODS}" ]] && [[ ${idx} -ge "${DEFAULT_NAMESPACE_PODS}" ]]; then
    NS="kube-system"
  else
    NS="default"
  fi
  if [[ -n "${BATCH_YAML}" ]]; then
    BATCH_YAML+=$'\n---\n'
  fi
  BATCH_YAML+=$(pod_manifest "$i" "$NS")
  ((BATCH_COUNT++))
  ((idx++))
  if [[ ${BATCH_COUNT} -ge ${BATCH_SIZE} ]]; then
    create_batch "${BATCH_YAML}"
    CREATED=$((CREATED + BATCH_COUNT))
    echo "[kwok] Progress: ${CREATED} pods created..."
    BATCH_YAML=""
    BATCH_COUNT=0
    sleep 0.3
  fi
done

if [[ ${BATCH_COUNT} -gt 0 ]]; then
  create_batch "${BATCH_YAML}"
  CREATED=$((CREATED + BATCH_COUNT))
fi

echo "[kwok] Created ${CREATED} new pods (total: ${POD_COUNT})"

