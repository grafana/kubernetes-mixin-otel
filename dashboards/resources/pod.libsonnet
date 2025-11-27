local config = import '../../config.libsonnet';

// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/pod.libsonnet
local localQueries = import './queries/pod.libsonnet';
local localVariables = import './variables/pod.libsonnet';
local k8sMixinPod = import 'github.com/kubernetes-monitoring/kubernetes-mixin/dashboards/resources/pod.libsonnet';

// Merge config with template so $._config resolves correctly
// The template accesses $._config which refers to the root object's _config
// Override queries and variables to use local ones instead of default
local merged = {
  _config: config._config,
  _queries: {
    pod: localQueries,
  },
  _variables: {
    pod: function(config) localVariables.pod(config),
  },
} + k8sMixinPod;

{
  _config: config._config,
  grafanaDashboards:: {
    'k8s-resources-pod.json': merged.grafanaDashboards['k8s-resources-pod.json']
                              {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        }
        for panel in merged.grafanaDashboards['k8s-resources-pod.json'].panels
      ],
    },
  },
}
