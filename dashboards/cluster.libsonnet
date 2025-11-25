local config = import 'github.com/sleepyfoodie/kubernetes-mixin/config.libsonnet';

// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/cluster-queries.libsonnet
local k8sMixinCluster = import 'github.com/sleepyfoodie/kubernetes-mixin/dashboards/resources/cluster.libsonnet';

// Self-referential object: template accesses $._config which refers to self._config
{
  _config: config._config,
  grafanaDashboards:: {
    'cluster.json': k8sMixinCluster.grafanaDashboards['k8s-resources-cluster.json'],
  },
}
