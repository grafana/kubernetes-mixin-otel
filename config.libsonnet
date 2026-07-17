local k8sMixinConfig = import 'github.com/kubernetes-monitoring/kubernetes-mixin/config.libsonnet';
local k8sAlertsConfig = (import 'github.com/kubernetes-monitoring/kubernetes-mixin/alerts/resource_alerts.libsonnet')._config;

k8sMixinConfig {
  _config+:: {
    cpuThrottlingPercent: k8sAlertsConfig.cpuThrottlingPercent,
    // REQUIRED: job selector for the OTel Collector running the k8sclusterreceiver.
    // Format is typically '{namespace}/{release-name}', e.g. 'job="monitoring/otel-collector-deployment"'.
    k8sclusterreceiverSelector: error 'k8sclusterreceiverSelector must be set in _config',

    // Output label names used in recording rules. Override if your Prometheus/Mimir
    // environment uses different label conventions.
    // Note: clusterLabel, namespaceLabel, and podLabel are inherited from kubernetes-mixin.
    nodeLabel: 'node',
    workloadLabel: 'workload',
    workloadTypeLabel: 'workload_type',
  },
}
