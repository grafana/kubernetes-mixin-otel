// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/pod.libsonnet
local localQueries = import './queries/pod.libsonnet';
local localVariables = import './variables/pod.libsonnet';
local k8sMixinPod = import 'github.com/kubernetes-sigs/kubernetes-mixin/dashboards/resources/pod.libsonnet';

// Override queries and variables to use local ones instead of default
// Takes config explicitly (called with $._config below) so mixin.libsonnet + { _config+:: {...} } overrides are honored.
local merged(config) = {
  _config: config,
  _queries: {
    pod: localQueries,
  },
  _variables: {
    pod: function(config) localVariables.pod(config),
  },
} + k8sMixinPod;

{
  local config = if std.objectHasAll($, '_config') then $._config else (import '../../config.libsonnet')._config,
  local dashboard = merged(config).grafanaDashboards['k8s-resources-pod.json'],
  grafanaDashboards+:: {
    'k8s-resources-pod.json': dashboard {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        }
        for panel in dashboard.panels
      ],
    },
  },
}
