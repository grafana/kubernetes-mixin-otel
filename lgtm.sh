#!/bin/bash

# Build the custom LGTM image with tar support
echo "Building custom LGTM image with tar support..."
docker build -t otel-lgtm-with-tar:latest -f DOCKER-BUILDER .

# Create k3d cluster
k3d cluster create otel-mixin \
    -v "$PWD"/k3d-volume:/k3d-volume

# Import the custom image into k3d
echo "Importing custom image into k3d cluster..."
k3d image import otel-lgtm-with-tar:latest -c otel-mixin

# Deploy the LGTM stack
kubectl apply -f lgtm.yaml