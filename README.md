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

This creates a simulated Kubernetes cluster with fake nodes/pods (default: 50 nodes, 200 pods), useful for testing dashboard queries without heavy resource usage. Grafana will be available at http://localhost:3001.

Optionally customize the cluster size:

```shell
make kwok NODE_COUNT=100 POD_COUNT=500
```

Enable [Beyla](https://grafana.com/docs/beyla/latest/) for auto-instrumentation tracing (traces the real Docker containers):

```shell
make kwok ENABLE_BEYLA=true
```

To delete the KWOK environment:

```shell
make kwok-down
```

## Configuration

Override `_config` when importing `mixin.libsonnet`:

```jsonnet
local mixin = import 'github.com/grafana/opentelemetry-mixin/mixin.libsonnet';

mixin {
  _config+:: {
    customAttributes: [{ label: 'env', operator: '=', value: 'prod' }],
  },
}
```

`customAttributes` — `{label, operator, value}` matchers appended to every query's label selectors.

Only use an attribute present on metrics from **both** the daemonset and deployment collector pipelines. Some panels (e.g. usage-vs-requests ratios) join a metric from each; if the attribute is missing on one side, that side returns no data and the whole panel goes blank.

## Architecture

For detailed architecture diagrams and setup options (k3d vs KWOK), see [scripts/README.md](scripts/README.md).
