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

# Disabled until Git Sync supports local rendering without requiring a public instance.
# kubectl --context k3d-kubernetes-mixin-otel apply -f grafana-image-renderer.yaml

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Deploy the OTel Kube Stack
helm upgrade --install opentelemetry-stack opentelemetry/opentelemetry-kube-stack \
    -f "$PWD"/otel-kube-stack-values.yaml \
    --kube-context k3d-kubernetes-mixin-otel \
    --namespace default \
    --wait \
    --timeout 300s
