# k3d Cluster (kubernetes-mixin-otel)

A real Kubernetes cluster with actual workloads using [k3d](https://k3d.io/).

1. [Create k3d cluster](lgtm.sh#L5-L7) with volume mounts for dashboards.
2. [Deploy LGTM stack](lgtm.sh#L13) as a Kubernetes Deployment via [lgtm.yaml](lgtm.yaml).
3. [Deploy OTel Collectors](lgtm.sh#L18-L26) via Helm (Deployment + DaemonSet).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Your Machine                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    k3d Cluster                              │   │
│   │                    (real K8s in Docker)                     │   │
│   │                                                             │   │
│   │   ┌─────────────────┐      ┌─────────────────┐              │   │
│   │   │ OTel Collector  │      │ OTel Collector  │              │   │
│   │   │ (Deployment)    │      │ (DaemonSet)     │              │   │
│   │   │                 │      │                 │              │   │
│   │   │ - k8s_cluster   │      │ - kubeletstats  │              │   │
│   │   │ - k8s_events    │      │ - hostmetrics   │              │   │
│   │   └────────┬────────┘      └────────┬────────┘              │   │
│   │            │                        │                       │   │
│   │            └──────────┬─────────────┘                       │   │
│   │                       │ OTLP :4318                          │   │
│   │                       ▼                                     │   │
│   │            ┌─────────────────────┐                          │   │
│   │            │   LGTM Pod          │                          │   │
│   │            │                     │                          │   │
│   │            │  ┌───────────────┐  │                          │   │
│   │            │  │ Grafana :3000 │──┼──────────────────────────┼───┼──▶ localhost:3000
│   │            │  ├───────────────┤  │                          │   │
│   │            │  │ Prometheus    │  │                          │   │
│   │            │  │ :9090         │──┼──────────────────────────┼───┼──▶ localhost:9090
│   │            │  ├───────────────┤  │                          │   │
│   │            │  │ OTLP Receiver │  │                          │   │
│   │            │  │ :4317/:4318   │  │                          │   │
│   │            │  └───────────────┘  │                          │   │
│   │            └─────────────────────┘                          │   │
│   │                                                             │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```
---

# KWOK cluster

1. [Create KWOK cluster](run-kwok-env.sh#L19-L24) to simulate a lightweight k8s cluster.
1. [Switch kubectl context](run-kwok-env.sh#L27-L28) to the KWOK cluster created in step 1.
1. [Setup KWOK Resources](run-kwok-env.sh#L31) defined in [kwok-pod-template.yaml](kwok-config/kwok-pod-template.yaml)
1. [Generate Kubeconfig for Docker](run-kwok-env.sh#L33-L68) to create a kubeconfig that Docker containers can use to talk to KWOK API.
1. [Start LGTM Stack](run-kwok-env.sh#L70-L86) in Port 3000 for grafana UI and Port 4317/4318 for OTLP receivers.
1. [Start kwok-stats-proxy](run-kwok-env.sh#L89) to simulate stats summary endpoint for KWOK kubeletstatsreceiver.
1. [Start Otel Collector](run-kwok-env.sh#L91-L111) with config from [kwok-otel-collector](kwok-config/kwok-otel-collector.yaml).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Your Machine                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────────┐     ┌──────────────────┐                     │
│   │  KWOK Cluster    │     │   Docker         │                     │
│   │  (simulated K8s) │     │                  │                     │
│   │                  │     │  ┌────────────┐  │                     │
│   │  - 50 fake nodes │◀────┼──│ stats-proxy│  │                     │
│   │  - 200 fake pods │     │  └────────────┘  │                     │
│   │                  │     │        │         │                     │
│   └────────▲─────────┘     │        ▼         │                     │
│            │               │  ┌────────────┐  │                     │
│            │               │  │ OTel       │  │                     │
│            └───────────────┼──│ Collector  │  │                     │
│                            │  └─────┬──────┘  │                     │
│                            │        │         │                     │
│                            │        ▼         │                     │
│                            │  ┌────────────┐  │                     │
│                            │  │   LGTM     │──┼───▶ localhost:3000  │
│                            │  │ (Grafana)  │  │     (Grafana UI)    │
│                            │  └────────────┘  │                     │
│                            └──────────────────┘                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Metrics flow in KWOK

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Docker Network                                  │
│                                                                     │
│  ┌─────────────────┐          ┌─────────────────────────────────┐   │
│  │ kwok-otel-      │  OTLP    │         LGTM Container          │   │
│  │ collector       │─────────▶│                                 │   │
│  │                 │ :4318    │  ┌──────────┐   ┌────────────┐  │   │
│  │ Receivers:      │          │  │ OTLP     │──▶│ Prometheus │  │   │
│  │ - kubeletstats  │          │  │ Receiver │   │ /Mimir     │  │   │
│  │ - k8s_cluster   │          │  └──────────┘   │ (internal) │  │   │
│  │ - hostmetrics   │          │                 └──────┬─────┘  │   │
│  └─────────────────┘          │                        │        │   │
│                               │                   PromQL│       │   │
│                               │                        ▼        │   │
│                               │                 ┌────────────┐  │   │
│                               │                 │  Grafana   │──┼───▶ :3000
│                               │                 └────────────┘  │   │
│                               └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Differences: KWOK vs k3d

| Aspect | KWOK | k3d |
|--------|------|-----|
| Cluster type | Simulated (no real containers) | Real K8s (containers in Docker) |
| Resource usage | Very light (~50MB) | Heavier (real workloads) |
| OTel Collectors | Docker container | Kubernetes Pods (Helm) |
| LGTM stack | Docker container | Kubernetes Pod |
| Prometheus port | Not exposed | Exposed (:9090) |
| Use case | Dashboard query testing | Full integration testing |