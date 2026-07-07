// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/queries/persistentvolumesusage.libsonnet
local localQueries = import './queries/persistentvolumesusage.libsonnet';
local localVariables = import './variables/persistentvolumesusage.libsonnet';
local k8sMixinPersistentVolume = import 'github.com/kubernetes-sigs/kubernetes-mixin/dashboards/persistentvolumesusage.libsonnet';

// Override queries and variables to use local ones instead of default
// Takes config explicitly (called with $._config below) so mixin.libsonnet + { _config+:: {...} } overrides are honored.
local merged(config) = {
  _config: config,
  _queries: {
    persistentVolume: localQueries,
  },
  _variables: {
    persistentVolume: function(config) localVariables.persistentVolume(config),
  },
} + k8sMixinPersistentVolume;

{
  local config = if std.objectHasAll($, '_config') then $._config else (import '../config.libsonnet')._config,
  local dashboard = merged(config).grafanaDashboards['persistentvolumesusage.json'],
  grafanaDashboards+:: {
    'persistentvolumesusage.json': dashboard {
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
