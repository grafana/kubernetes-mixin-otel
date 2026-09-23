// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/namespace.libsonnet
local localQueries = import './queries/namespace.libsonnet';
local localVariables = import './variables/namespace.libsonnet';
local k8sMixinNamespace = import 'github.com/kubernetes-sigs/kubernetes-mixin/dashboards/resources/namespace.libsonnet';

// Takes config explicitly (called with $._config below) so mixin.libsonnet + { _config+:: {...} } overrides are honored.
local merged(config) = {
  _config: config,
  _queries: {
    namespace: localQueries,
  },
  _variables: {
    namespace: function(config) localVariables.namespace(config),
  },
} + k8sMixinNamespace;

// Helper to update joinByField transformation from 'pod' to 'k8s_pod_name'
local updateTransformations(transformations) =
  [
    if t.id == 'joinByField' then
      t { options+: { byField: 'k8s_pod_name' } }
    else
      t
    for t in transformations
  ];

{
  grafanaDashboards+:: {
    'k8s-resources-namespace.json': merged($._config).grafanaDashboards['k8s-resources-namespace.json']
                                    {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        } + (
          if std.objectHas(panel, 'transformations') then
            { transformations: updateTransformations(panel.transformations) }
          else
            {}
        )
        for panel in merged($._config).grafanaDashboards['k8s-resources-namespace.json'].panels
      ],
    },
  },
}
