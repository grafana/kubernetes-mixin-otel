#!/bin/bash
set -euo pipefail

k3d cluster delete kubernetes-mixin-otel

# Create k3d cluster
k3d cluster create kubernetes-mixin-otel \
    -v "$PWD"/../k3d-volume:/k3d-volume

# Wait for cluster to be ready
kubectl --context k3d-kubernetes-mixin-otel wait --for=condition=Ready nodes --all --timeout=300s

# Deploy the LGTM stack
kubectl --context k3d-kubernetes-mixin-otel apply -f lgtm.yaml

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install otel-collector-deployment open-telemetry/opentelemetry-collector \
    -n default \
    -f otel-collector-deployment.values.yaml

helm upgrade --install otel-collector-daemonset open-telemetry/opentelemetry-collector \
    -n default \
    -f otel-collector-daemonset.values.yaml
