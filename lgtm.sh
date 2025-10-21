#!/bin/bash


k3d cluster create otel-mixin \
    -v "$PWD"/k3d-volume:/k3d-volume

kubectl apply -f lgtm.yaml