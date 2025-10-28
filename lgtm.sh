#!/bin/bash

k3d cluster delete otel-mixin

# Create k3d cluster
k3d cluster create otel-mixin \
    -v "$PWD"/k3d-volume:/k3d-volume \

# Import the custom image into k3d
echo "Importing custom image into k3d cluster..."
k3d image import grafana/otel-lgtm:latest -c otel-mixin

# Deploy the LGTM stack
kubectl apply -f lgtm.yaml