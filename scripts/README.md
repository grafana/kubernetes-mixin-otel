Our dev environment runs two types of clusters. See below for a description of both k3d and KWOK. 

# k3d Cluster (kubernetes-mixin-otel)

A real Kubernetes cluster with actual workloads using [k3d](https://k3d.io/). Our script does the following on `make dev` command:

1. [Create k3d cluster](lgtm.sh#L5-L7) with volume mounts for dashboards.
2. [Deploy LGTM stack](lgtm.sh#L13) as a Kubernetes Deployment via [lgtm.yaml](lgtm.yaml).
3. [Deploy OTel Collectors](lgtm.sh#L18-L26) via Helm (Deployment + DaemonSet).

## Architecture

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                              k3d Cluster                                      │
│                                                                               │
│  ┌───────────────────────────────┐    ┌───────────────────────────────┐       │
│  │  OTel Collector (Deployment)  │    │  OTel Collector (DaemonSet)   │       │
│  │  (1 replica)                  │    │  (1 per node)                 │       │
│  │                               │    │                               │       │
│  │  Receivers:                   │    │  Receivers:                   │       │
│  │  ┌─────────────────────────┐  │    │  ┌─────────────────────────┐  │       │
│  │  │ k8s_cluster (preset)    │  │    │  │ kubeletstats (preset)   │  │       │
│  │  │ • node metrics          │  │    │  │ • pod CPU/memory        │  │       │
│  │  │ • pod counts            │  │    │  │ • container stats       │  │       │
│  │  │ • deployment status     │  │    │  ├─────────────────────────┤  │       │
│  │  └─────────────────────────┘  │    │  │ hostmetrics             │  │       │
│  │               │               │    │  │ • node CPU/memory/disk  │  │       │
│  │               │               │    │  └─────────────────────────┘  │       │
│  └───────────────┼───────────────┘    └───────────────┼───────────────┘       │
│                  │                                    │                       │
│                  └──────────────┬─────────────────────┘                       │
│                                 │                                             │
│                                 │  OTLP/HTTP                                  │
│                                 │  http://lgtm:9090/api/v1/otlp               │
│                                 ▼                                             │
│                  ┌───────────────────────────────────────┐                    │
│                  │            LGTM Pod                   │                    │
│                  │                                       │                    │
│                  │  ┌─────────────────────────────────┐  │                    │
│                  │  │     OTLP Receiver (:9090)       │  │                    │
│                  │  │     /api/v1/otlp                │  │                    │
│                  │  └───────────────┬─────────────────┘  │                    │
│                  │                  │                    │                    │
│                  │                  ▼                    │                    │
│                  │  ┌─────────────────────────────────┐  │                    │
│                  │  │     Prometheus / Mimir          │──┼───▶ localhost:9090 │
│                  │  │     (stores metrics in TSDB)    │  │                    │
│                  │  └───────────────┬─────────────────┘  │                    │
│                  │                  │ PromQL             │                    │
│                  │                  ▼                    │                    │
│                  │  ┌─────────────────────────────────┐  │                    │
│                  │  │         Grafana                 │──┼───▶ localhost:3000 │
│                  │  │     (dashboards & queries)      │  │                    │
│                  │  └─────────────────────────────────┘  │                    │
│                  │                                       │                    │
│                  └───────────────────────────────────────┘                    │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

### OTel Collectors Summary

| Collector | Type | What It Collects | Runs On |
|-----------|------|------------------|---------|
| **Deployment** | Single pod | Cluster-wide metrics (nodes, deployments, quotas) | Any node |
| **DaemonSet** | Pod per node | Per-node metrics (kubelet stats, host metrics) | Every node |

---

# KWOK cluster

A lightweight simulated Kubernetes cluster using [KWOK](https://kwok.sigs.k8s.io/) (Kubernetes Without Kubelet). No real containers run — just a fake API server with simulated nodes and pods. KWOK has a way to fake container metrics but only for Prometheus. In our KWOK environment, we have `stats-proxy` as a mini service to fake container metrics for Otel. Our script does the following on `make kwok` command:

1. [Create KWOK cluster](run-kwok-env.sh#L19-L24) to simulate a lightweight k8s cluster.
1. [Switch kubectl context](run-kwok-env.sh#L27-L28) to the KWOK cluster created in step 1.
1. [Setup KWOK Resources](run-kwok-env.sh#L31) defined in [kwok-pod-template.yaml](kwok-config/kwok-pod-template.yaml)
1. [Generate Kubeconfig for Docker](run-kwok-env.sh#L33-L68) to create a kubeconfig that Docker containers can use to talk to KWOK API.
1. [Start LGTM Stack](run-kwok-env.sh#L70-L86) in Port 3000 for grafana UI and Port 4317/4318 for OTLP receivers.
1. [Start kwok-stats-proxy](run-kwok-env.sh#L89) to simulate stats summary endpoint for KWOK kubeletstatsreceiver.
1. [Start Otel Collector](run-kwok-env.sh#L91-L111) with config from [kwok-otel-collector](kwok-config/kwok-otel-collector.yaml).
1. (Optional) [Start Beyla](run-kwok-beyla.sh) for auto-instrumentation tracing when `ENABLE_BEYLA=true`.

### Beyla Tracing (Optional)

[Grafana Beyla](https://grafana.com/docs/beyla/latest/) provides eBPF-based auto-instrumentation for tracing **Grafana dashboard query performance**. Enable it with:

```shell
make kwok ENABLE_BEYLA=true
```

This instruments:
- **Port 3000** (Grafana) - incoming dashboard/API requests
- **Port 9090** (Prometheus/Mimir) - metric queries from Grafana

Traces appear in **Grafana Tempo** (Explore → Tempo).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              Your Machine                                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌───────────────────────┐       ┌───────────────────────────────────────────────┐ │
│   │  KWOK Cluster         │       │   Docker                                      │ │
│   │  (simulated K8s API)  │       │                                               │ │
│   │                       │       │   ┌─────────────────────────────────────────┐ │ │
│   │  - 50 fake nodes      │◀──────┼───│ stats-proxy                             │ │ │
│   │  - 200 fake pods      │       │   │ (simulates kubelet /stats/summary)      │ │ │
│   │  - No real containers │       │   └─────────────────────────────────────────┘ │ │
│   │                       │       │                       ▲                       │ │
│   └───────────▲───────────┘       │                       │ scrapes               │ │
│               │                   │                       │                       │ │
│               │ queries           │   ┌───────────────────┴─────────────────────┐ │ │
│               │ K8s API           │   │ OTel Collector                          │ │ │
│               │                   │   │                                         │ │ │
│               └───────────────────┼───│ Receivers:                              │ │ │
│                                   │   │  • kubeletstats (via stats-proxy)       │ │ │
│                                   │   │  • k8s_cluster (queries KWOK API)       │ │ │
│                                   │   │  • hostmetrics (Docker host stats)      │ │ │
│                                   │   └─────────────────────┬───────────────────┘ │ │
│                                   │                         │                     │ │
│                                   │                         │ OTLP :4318          │ │
│                                   │                         ▼                     │ │
│                                   │   ┌─────────────────────────────────────────┐ │ │
│                                   │   │ LGTM                                    │ │ │
│                                   │   │                                         │ │ │
│                                   │   │  OTLP Receiver ──▶ Prometheus/Mimir     │ │ │
│                                   │   │       │                 │               │ │ │
│                                   │   │       │            PromQL│              │ │ │
│                                   │   │       ▼                 ▼               │ │ │
│                                   │   │     Tempo            Grafana ───────────┼─┼─┼──▶ localhost:3000
│                                   │   │       ▲                 │               │ │ │
│                                   │   └───────┼─────────────────┼───────────────┘ │ │
│                                   │           │                 │                 │ │
│                                   │   ┌───────┴─────────────────┴───────────────┐ │ │
│                                   │   │ Beyla (optional, ENABLE_BEYLA=true)     │ │ │
│                                   │   │                                         │ │ │
│                                   │   │  eBPF auto-instrumentation:             │ │ │
│                                   │   │   • traces Grafana queries (:3000)      │ │ │
│                                   │   │   • traces Prometheus queries (:9090)   │ │ │
│                                   │   └─────────────────────────────────────────┘ │ │
│                                   │                                               │ │
│                                   └───────────────────────────────────────────────┘ │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Key Differences: KWOK vs k3d

| Aspect | KWOK | k3d |
|--------|------|-----|
| Cluster type | Simulated (no real containers) | Real K8s (containers in Docker) |
| Resource usage | Very light (~50MB) | Heavier (real workloads) |
| OTel Collectors | 1 Docker container | 2 Kubernetes Pods (Helm) |
| LGTM stack | Docker container | Kubernetes Pod |
| Kubelet stats | Fake (via stats-proxy) | Real (actual kubelet) |
| Host metrics | From Docker host | From k3d node containers |
| OTLP endpoint | `:4318` (standard) | `:9090/api/v1/otlp` (Mimir native) |
| Prometheus port | Not exposed | Exposed (:9090) |
| Use case | Dashboard query testing | Full integration testing |
