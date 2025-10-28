#!/bin/bash

k3d cluster delete otel-mixin

# Create k3d cluster
k3d cluster create otel-mixin \
    -v "$PWD"/k3d-volume:/k3d-volume \
    -v "$PWD"/datasource:/datasource \
    -p "3000:3000@loadbalancer" \
    -p "4317:4317@loadbalancer" \
    -p "4318:4318@loadbalancer" \

# Import the custom image into k3d
echo "Importing custom image into k3d cluster..."
k3d image import grafana/otel-lgtm:latest -c otel-mixin

# Deploy the LGTM stack
kubectl apply -f lgtm.yaml