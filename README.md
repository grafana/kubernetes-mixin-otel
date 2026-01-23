# kubernetes-mixin-otel

## Local development

Run the following command to setup a local [k3d](https://k3d.io/stable/) cluster:

```shell
make dev
```

You should see the following output if successful:

```shell
╔═══════════════════════════════════════════════════════════════╗
║             🚀 Development Environment Ready! 🚀              ║
║                                                               ║
║   Run `make dev-port-forward`                                 ║
║   Grafana will be available at http://localhost:3000          ║
║                                                               ║
║   Data will be available in a few minutes.                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

To delete the cluster, run the following:

```shell
make dev-down
```

## KWOK (lightweight alternative)

For a lightweight simulated cluster (no real containers), use [KWOK](https://kwok.sigs.k8s.io/):

```shell
make kwok
```

This creates a simulated Kubernetes cluster with fake nodes/pods (default: 50 nodes, 200 pods), useful for testing dashboard queries without heavy resource usage.

Optionally customize the cluster size:

```shell
make kwok NODE_COUNT=100 POD_COUNT=500
```

To delete the KWOK environment:

```shell
make kwok-down
```
## Architecture

For detailed architecture diagrams and setup options (k3d vs KWOK), see [scripts/README.md](scripts/README.md).
