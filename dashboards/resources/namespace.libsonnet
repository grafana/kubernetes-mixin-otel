local config = import '../../config.libsonnet';

// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/namespace.libsonnet
local localQueries = import './queries/namespace.libsonnet';
local localVariables = import './variables/namespace.libsonnet';
local k8sMixinNamespace = import 'github.com/kubernetes-monitoring/kubernetes-mixin/dashboards/resources/namespace.libsonnet';

// Override queries and variables to use local ones instead of default
local merged = {
  _config: config._config,
  _queries: {
    namespace: localQueries,
  },
  _variables: {
    namespace: function(config) localVariables.namespace(config),
  },
} + k8sMixinNamespace;

{
  _config: config._config,
  grafanaDashboards+:: {
    'k8s-resources-namespace.json': merged.grafanaDashboards['k8s-resources-namespace.json']
                                    {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        }
        for panel in merged.grafanaDashboards['k8s-resources-namespace.json'].panels
      ],
    },
  },
}
