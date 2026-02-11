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
1. [Start LGTM Stack](run-kwok-env.sh#L70-L86) in Port 3001 for grafana UI and Port 4317/4318 for OTLP receivers.
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
│   │  - 1 node (default)   │◀──────┼───│ stats-proxy                             │ │ │
│   │  - 10 pods (parity)   │       │   │ (simulates kubelet /stats/summary)      │ │ │
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
│                                   │   │     Tempo            Grafana ───────────┼─┼─┼──▶ localhost:3001
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

### Series parity with dev

With default settings (`make kwok`, `POD_COUNT=0`), KWOK is tuned so **series-per-metric counts match dev** for most metrics:

- **Pods/containers**: Only cluster workloads are created (no batch pods): 6 deployments (replicas=1), 2 daemonsets, 2 jobs → 10 pods, 11 containers. Resource requests/limits are set so `k8s_container_cpu_limit`=1, `k8s_container_cpu_request`=3, `k8s_container_memory_limit_bytes`=2, `k8s_container_memory_request_bytes`=3.
- **Memory available**: `container_memory_available_bytes` and `k8s_pod_memory_available_bytes` are emitted only when a container/pod has a memory **limit** (stats-proxy mirrors real kubelet behavior).

Remaining gaps (optional to fix):

- **`otelcol_receiver_*`**: Dev has 1 (one collector scrape with one receiver in use); KWOK main collector has multiple receivers, so count is 2+. Matching would require a single-receiver collector config.
- **`target_info`**: Dev has 32 (Prometheus scrape targets from the full LGTM/k3d setup); KWOK has 1. Matching would require configuring LGTM’s Prometheus with the same number of static scrape targets as dev (see below).

#### What “32 scrape targets” means

In **dev (k3d)**, Prometheus runs inside the LGTM pod and uses **Kubernetes service discovery** to find scrape targets: it discovers services/pods in the cluster (e.g. the OTel collector deployment, the OTel collector DaemonSet pods, LGTM itself, etc.). That adds up to **32 targets**. Each target produces one `target_info` series (with labels like `job`, `instance`).

In **KWOK**, LGTM runs as a single Docker container. Metrics reach it mainly via **OTLP** (the collector pushes to `:4318`). Any Prometheus scrape inside LGTM typically has only **one** target (e.g. the collector’s `:8889` metrics endpoint), so you get **1** `target_info`.

To match dev you’d have to make Prometheus inside LGTM scrape **32 targets**. That would mean:

1. **Override Prometheus config** in the LGTM container (mount a custom config file; the exact path depends on the `grafana/otel-lgtm` image).
2. **Define 32 targets** in that config. In Prometheus, each entry in `static_configs` is one target and one `target_info`. So you’d need something like:

```yaml
# Conceptual: 32 targets so target_info has 32 series (like dev)
scrape_configs:
  - job_name: 'parity-targets'
    static_configs:
      - targets: ['host.docker.internal:8889']   # target 1 (real collector)
      - targets: ['host.docker.internal:8890']   # target 2 (need something listening)
      - targets: ['host.docker.internal:8891']   # target 3
      # ... 29 more targets
```

So you’d need **32 different endpoints** that expose Prometheus metrics (e.g. 32 ports, or 32 different hosts). The image doesn’t document a standard way to mount a custom Prometheus/Mimir config, so you’d be relying on internal paths and possible image changes. In practice, matching `target_info` this way is usually not worth it for KWOK.
