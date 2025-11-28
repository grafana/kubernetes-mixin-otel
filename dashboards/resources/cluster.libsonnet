local config = import '../../config.libsonnet';

// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/cluster.libsonnet
local localQueries = import './queries/cluster.libsonnet';
local localVariables = import './variables/cluster.libsonnet';
local k8sMixinCluster = import 'github.com/kubernetes-monitoring/kubernetes-mixin/dashboards/resources/cluster.libsonnet';

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

local fixJoinByField(transformation) =
  if std.objectHas(transformation, 'id') && transformation.id == 'joinByField'
  then transformation {
    options+: {
      byField: 'Time',
    },
  }
  else transformation;

{
  _config: config._config,
  grafanaDashboards+:: {
    'k8s-resources-cluster.json': merged.grafanaDashboards['k8s-resources-cluster.json']
                                  {
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
        for panel in merged.grafanaDashboards['k8s-resources-cluster.json'].panels
      ],
    },
  },
}
