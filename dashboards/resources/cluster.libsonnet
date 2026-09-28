// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/cluster.libsonnet
local localQueries = import './queries/cluster.libsonnet';
local localVariables = import './variables/cluster.libsonnet';
local k8sMixinCluster = import 'github.com/kubernetes-sigs/kubernetes-mixin/dashboards/resources/cluster.libsonnet';

// Override queries and variables to use local ones instead of default
// Takes config explicitly (called with $._config below) so mixin.libsonnet + { _config+:: {...} } overrides are honored.
local merged(config) = {
  _config: config,
  _queries: {
    cluster: localQueries,
  },
  _variables: {
    cluster: function(config) localVariables.cluster(config),
  },
} + k8sMixinCluster;

// Work around to fix joinByField transformation
// See this issue: https://github.com/grafana/grafana/issues/113663
local fixJoinByField(transformation) =
  if std.objectHas(transformation, 'id') && transformation.id == 'joinByField'
  then transformation {
    options+: {
      byField: 'Time',
    },
  }
  else transformation;

{
  local config = if std.objectHasAll($, '_config') then $._config else (import '../../config.libsonnet')._config,
  local dashboard = merged(config).grafanaDashboards['k8s-resources-cluster.json'],
  grafanaDashboards+:: {
    'k8s-resources-cluster.json': dashboard {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        } + (
          if std.objectHas(panel, 'transformations')
          then {
            transformations: [fixJoinByField(t) for t in panel.transformations],
          }
          else {}
        )
        for panel in dashboard.panels
      ],
    },
  },
}
