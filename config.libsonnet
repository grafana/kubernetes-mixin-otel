local k8sMixinConfig = import 'github.com/kubernetes-sigs/kubernetes-mixin/config.libsonnet';
local k8sAlertsConfig = (import 'github.com/kubernetes-sigs/kubernetes-mixin/alerts/resource_alerts.libsonnet')._config;

k8sMixinConfig {
  _config+:: {
    cpuThrottlingPercent: k8sAlertsConfig.cpuThrottlingPercent,
    resourceQuotaAlmostFullPercent: 90,
    resourceQuotaPodFitResources: ['pods', 'requests.cpu', 'requests.memory', 'limits.cpu', 'limits.memory'],
    runbookURLPattern: 'https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-%s',
    custom+: {
      attributes: [],
      groupingAttributes: [],
    },
  },
}
