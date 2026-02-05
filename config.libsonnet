local k8sMixinConfig = import 'github.com/kubernetes-monitoring/kubernetes-mixin/config.libsonnet';
local k8sAlertsConfig = (import 'github.com/kubernetes-monitoring/kubernetes-mixin/alerts/resource_alerts.libsonnet')._config;

k8sMixinConfig {
  _config+:: {
    // OpenTelemetry semantic conventions use k8s_cluster_name
    clusterLabel: 'k8s_cluster_name',
    cpuThrottlingPercent: k8sAlertsConfig.cpuThrottlingPercent,
  },
}
