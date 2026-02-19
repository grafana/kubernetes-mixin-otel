#!/bin/bash
# Create Deployment, DaemonSet, Job in the Kwok cluster so k8s_cluster receiver
# emits k8s_deployment_*, k8s_replicaset_*, k8s_daemonset_*, k8s_job_* metrics (match dev).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-queries-testing}"
CONTEXT="kwok-${CLUSTER_NAME}"
MANIFEST="${SCRIPT_DIR}/kwok-config/kwok-cluster-workloads.yaml"

echo "[kwok] Applying cluster workloads (Deployment, DaemonSet, Job) for k8s_cluster metrics..."
kubectl --context "${CONTEXT}" apply -f "${MANIFEST}"
