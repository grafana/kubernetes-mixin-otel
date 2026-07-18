local config = import '../config.libsonnet';

// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/queries/persistentvolumesusage.libsonnet
local localQueries = import './queries/persistentvolumesusage.libsonnet';
local localVariables = import './variables/persistentvolumesusage.libsonnet';
local k8sMixinPersistentVolume = import 'github.com/kubernetes-monitoring/kubernetes-mixin/dashboards/persistentvolumesusage.libsonnet';

// Override queries and variables to use local ones instead of default
local merged = {
  _config: config._config,
  _queries: {
    persistentVolume: localQueries,
  },
  _variables: {
    persistentVolume: function(config) localVariables.persistentVolume(config),
  },
} + k8sMixinPersistentVolume;

{
  _config: config._config,
  grafanaDashboards+:: {
    'persistentvolumesusage.json': merged.grafanaDashboards['persistentvolumesusage.json']
                                   {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        }
        for panel in merged.grafanaDashboards['persistentvolumesusage.json'].panels
      ],
    },
  },
}
