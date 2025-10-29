#!/bin/bash

k3d cluster delete kubernetes-mixin-otel

# Create k3d cluster (no port mappings - using port-forward instead)
k3d cluster create kubernetes-mixin-otel \
    -v "$PWD"/k3d-volume:/k3d-volume

# Import the custom image into k3d
echo "Importing custom image into k3d cluster..."
k3d image import grafana/otel-lgtm:latest -c kubernetes-mixin-otel

# Deploy the LGTM stack
kubectl apply -f lgtm.yaml

# Wait for pods to be ready
echo "Waiting for LGTM pod to be ready..."
kubectl wait --for=condition=Ready pods -l app=lgtm --timeout=300s

# Start port-forwarding in the background
echo "Setting up port forwarding..."
kubectl port-forward service/lgtm 3000:3000 4317:4317 4318:4318 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

echo ""
echo "✅ LGTM stack deployed and port-forwarded!"
echo "🌐 Grafana UI: http://localhost:3000"
echo "📊 OTEL gRPC: localhost:4317"  
echo "📊 OTEL HTTP: localhost:4318"
echo ""
echo "💡 Port-forward running in background (PID: $PORT_FORWARD_PID)"
echo "💡 To stop: kill $PORT_FORWARD_PID"