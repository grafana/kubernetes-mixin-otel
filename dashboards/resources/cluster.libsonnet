local config = import '../../config.libsonnet';

// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/cluster.libsonnet
local localQueries = import './queries/cluster.libsonnet';
local localVariables = import './variables/cluster.libsonnet';
local k8sMixinCluster = import 'github.com/kubernetes-monitoring/kubernetes-mixin/dashboards/resources/cluster.libsonnet';

// Merge config with template so $._config resolves correctly
// The template accesses $._config which refers to the root object's _config
// Override queries and variables to use local ones instead of default
local merged = {
  _config: config._config,
  _queries: {
    cluster: localQueries,
  },
  _variables: {
    cluster: function(config) localVariables.cluster(config),
  },
} + k8sMixinCluster;

{
  _config: config._config,
  grafanaDashboards:: {
    'k8s-resources-cluster.json': merged.grafanaDashboards['k8s-resources-cluster.json']
                                  {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        }
        for panel in merged.grafanaDashboards['k8s-resources-cluster.json'].panels
      ],
    },
  },
}
