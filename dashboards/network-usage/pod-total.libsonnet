// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/network-usage/queries/pod-total.libsonnet
local localQueries = import './queries/pod-total.libsonnet';
local localVariables = import './variables/pod-total.libsonnet';
local k8sMixinPodTotal = import 'github.com/kubernetes-sigs/kubernetes-mixin/dashboards/network-usage/pod-total.libsonnet';

// Override queries and variables to use local ones instead of default
// Takes config explicitly (called with $._config below) so mixin.libsonnet + { _config+:: {...} } overrides are honored.
local merged(config) = {
  _config: config,
  _queries: {
    podTotal: localQueries,
  },
  _variables: {
    podTotal: function(config) localVariables.podTotal(config),
  },
} + k8sMixinPodTotal;

{
  local config = if std.objectHasAll($, '_config') then $._config else (import '../../config.libsonnet')._config,
  local dashboard = merged(config).grafanaDashboards['pod-total.json'],
  grafanaDashboards+:: {
    'pod-total.json': dashboard {
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
