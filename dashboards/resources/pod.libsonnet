// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/resources/queries/pod.libsonnet
local localQueries = import './queries/pod.libsonnet';
local localVariables = import './variables/pod.libsonnet';
local k8sMixinPod = import 'github.com/kubernetes-sigs/kubernetes-mixin/dashboards/resources/pod.libsonnet';

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
  grafanaDashboards+:: {
    'k8s-resources-pod.json': merged($._config).grafanaDashboards['k8s-resources-pod.json']
                              {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        }
        for panel in merged($._config).grafanaDashboards['k8s-resources-pod.json'].panels
      ],
    },
  },
}
