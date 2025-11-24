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

## Json dashboards

Run the following command to generate dashboards into json files

```shell
make generate-dashboards
```

The dashboards will output into `generate-dashboards` folder.