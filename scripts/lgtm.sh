#!/bin/bash
set -euo pipefail

# Create k3d cluster
k3d cluster create kubernetes-mixin-otel \
    -v "$PWD"/../dashboards_out:/kubernetes-mixin/dashboards_out

# Wait for cluster to be ready
kubectl --context k3d-kubernetes-mixin-otel wait --for=condition=Ready nodes --all --timeout=300s

# Deploy the LGTM stack
kubectl --context k3d-kubernetes-mixin-otel apply -f lgtm.yaml

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
