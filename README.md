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
    extraAttributes: [{ label: 'asserts_env', operator: '=', value: 'prod' }],
    extraGroupingAttributes: ['asserts_env', 'asserts_site'],
  },
}
```

- `extraAttributes` — `{label, operator, value}` selectors appended to every query's label matchers.
- `extraGroupingAttributes` — label names appended to every `by(...)`/`on(...)` clause, so the attribute survives aggregation. Scalar stat panels (no `by(...)`) are left as a single value and are unaffected.

The attribute must be a resource attribute on the underlying metrics (e.g. a `resource` processor, see `resource/k8sclustername` in the values files) present on **both** the daemonset and deployment collector pipelines — some queries join across them, and a one-sided attribute makes the join match nothing.

The cluster/node/namespace/pod dashboard variables are built from `k8s_node_condition_ready`, `k8s_namespace_phase`, and `k8s_pod_phase`, all emitted by the **deployment** collector's `k8s_cluster` receiver. If `extraAttributes` isn't also present there, the variable dropdowns will come back empty rather than merely too broad.

## Architecture

For detailed architecture diagrams and setup options (k3d vs KWOK), see [scripts/README.md](scripts/README.md).
