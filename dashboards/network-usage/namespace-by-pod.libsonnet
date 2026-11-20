// Import kubernetes-mixin template directly from vendor
// It will use local queries from dashboards/network-usage/queries/namespace-by-pod.libsonnet
local localQueries = import './queries/namespace-by-pod.libsonnet';
local localVariables = import './variables/namespace-by-pod.libsonnet';
local k8sMixinNamespaceByPod = import 'github.com/kubernetes-sigs/kubernetes-mixin/dashboards/network-usage/namespace-by-pod.libsonnet';

// Override queries and variables to use local ones instead of default
// Takes config explicitly (called with $._config below) so mixin.libsonnet + { _config+:: {...} } overrides are honored.
local merged(config) = {
  _config: config,
  _queries: {
    namespaceByPod: localQueries,
  },
  _variables: {
    namespaceByPod: function(config) localVariables.namespaceByPod(config),
  },
} + k8sMixinNamespaceByPod;

// Upstream joins and renames on `pod`; ours is `k8s_pod_name`. The rename to
// `Pod` also keeps the drill-down link's ${__data.fields.Pod} working.
local updateTransformation(t) =
  if t.id == 'joinByField' then
    t { options+: { byField: 'k8s_pod_name' } }
  else if t.id == 'organize' then
    local renamePod(o) = { [if k == 'pod' then 'k8s_pod_name' else k]: o[k] for k in std.objectFields(o) };
    t {
      options+: {
        indexByName: renamePod(t.options.indexByName),
        renameByName: renamePod(t.options.renameByName),
      },
    }
  else
    t;

// Upstream's single-select `var-namespace=${namespace}` renders a multi-select
// value as `{a,b}`, which the Pod dashboard reads as one namespace.
local fixLinkUrl(url) =
  std.strReplace(url, 'var-cluster=${cluster}&var-namespace=${namespace}', '${cluster:queryparam}&${namespace:queryparam}');

local updateOverride(o) =
  o {
    properties: [
      if p.id == 'links' then p { value: [l { url: fixLinkUrl(l.url) } for l in p.value] } else p
      for p in o.properties
    ],
  };

{
  local config = if std.objectHasAll($, '_config') then $._config else (import '../../config.libsonnet')._config,
  local dashboard = merged(config).grafanaDashboards['namespace-by-pod.json'],
  grafanaDashboards+:: {
    'namespace-by-pod.json': dashboard {
      panels: [
        panel {
          datasource: {
            type: 'datasource',
            uid: '${datasource}',
          },
        }
        // Upstream labels gauges `$namespace`, which with a multi-select variable
        // puts every selected namespace's name on each per-namespace gauge.
        + (if panel.type == 'gauge' then {
             fieldConfig+: { defaults+: { displayName: '${__field.labels.k8s_namespace_name}' } },
           } else {})
        + (if std.objectHas(panel, 'transformations') then {
             transformations: [updateTransformation(t) for t in panel.transformations],
             fieldConfig+: { overrides: [updateOverride(o) for o in panel.fieldConfig.overrides] },
           } else {})
        for panel in dashboard.panels
      ],
    },
  },
}
