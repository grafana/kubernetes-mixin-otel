#!/bin/bash
set -euo pipefail

# Create k3d cluster
k3d cluster create kubernetes-mixin-otel \
    -v "$PWD"/provisioning:/kubernetes-mixin-otel/provisioning \
    -v "$PWD"/../dashboards_out:/kubernetes-mixin-otel/dashboards_out

# Wait for cluster to be ready
kubectl --context k3d-kubernetes-mixin-otel wait --for=condition=Ready nodes --all --timeout=300s

# Deploy the LGTM stack
kubectl --context k3d-kubernetes-mixin-otel apply -f lgtm.yaml

# Back the static local PersistentVolume with a small tmpfs mount, then
# deploy a PVC-backed workload so the Persistent Volumes dashboard has data.
# A plain directory would sit on the node's overlayfs root: capacity would
# report the whole node disk, and inode stats would be zero when the Docker
# backing filesystem is btrfs (statfs f_files=0). tmpfs reports a real 1Gi
# capacity and real inode counts; nr_inodes is kept small so the writer's
# ~20 files register as visible inode utilisation on the dashboard.
docker exec k3d-kubernetes-mixin-otel-server-0 sh -c \
    'mkdir -p /var/lib/kubernetes-mixin-otel/pv-writer && mount -t tmpfs -o size=1g,nr_inodes=512 tmpfs /var/lib/kubernetes-mixin-otel/pv-writer'
kubectl --context k3d-kubernetes-mixin-otel apply -f pv-workload.yaml

# Disabled until Git Sync supports local rendering without requiring a public instance.
# kubectl --context k3d-kubernetes-mixin-otel apply -f grafana-image-renderer.yaml

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install otel-collector-deployment open-telemetry/opentelemetry-collector \
    -n default \
    -f otel-collector-deployment.values.yaml

helm upgrade --install otel-collector-daemonset open-telemetry/opentelemetry-collector \
    -n default \
    -f otel-collector-daemonset.values.yaml
