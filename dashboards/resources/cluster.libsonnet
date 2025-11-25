local config = import 'github.com/sleepyfoodie/kubernetes-mixin/config.libsonnet';

// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/cluster-queries.libsonnet
local k8sMixinCluster = import 'github.com/sleepyfoodie/kubernetes-mixin/dashboards/resources/cluster.libsonnet';
local localQueries = import './queries/cluster-queries.libsonnet';

// Merge config with template so $._config resolves correctly
// The template accesses $._config which refers to the root object's _config
// Override queries to use local queries instead of default
local merged = {
  _config: config._config,
  _queries: {
    cluster: localQueries,
  },
} + k8sMixinCluster;

{
  _config: config._config,
  grafanaDashboards:: {
    'cluster.json': merged.grafanaDashboards['k8s-resources-cluster.json'],
  },
}
