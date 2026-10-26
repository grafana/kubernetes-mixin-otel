// Imported by queries and alerts — never import those back.
local selectors = import './selectors.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local podMaxBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name'];

// pod phases are 1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown
// known issue here: https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36819
local phaseActive(phaseValues, config) =
  local phaseSelector = selectors.selector('k8s_pod_phase', phaseValues, config=config);
  promql.clamp_max({
    expr: promql.max({
      by: podMaxBy,
      expr: promql.or({
        left: promql.eq({ left: phaseSelector, right: '1' }),
        right: promql.eq({ left: phaseSelector, right: '2' }),
      }),
    }),
    max: 1,
  });

{
  // Joins expr against the active-pod filter: expr * on (...) group_left() ...
  activeOnly(expr, phaseValues, config)::
    promql.mul({
      left: expr,
      right: phaseActive(phaseValues, config),
      on: podMaxBy,
      groupLeft: [],
    }),
}
