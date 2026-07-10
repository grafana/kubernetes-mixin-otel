// Shared query builders for all resource dashboards, built on the tsqtsq
// jsonnet library (the same PromQL query API as the TypeScript tsqtsq).
//
// The helpers here encode this mixin's conventions -- OTel semantic
// convention labels, and de-duplication of series via max by the container
// identity labels -- expressed through the shared tsqtsq primitives.
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local maxBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name', 'k8s_container_name'];
local podMaxBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name'];

// Metric selector: dashboard variable filters (regex-matched values) plus
// optional extra selectors (e.g. direction="receive").
local selector(metric, values, selectors=[]) =
  tsqtsq.Expression({
    metric: metric,
    values: values,
    defaultOperator: tsqtsq.MatchingOperator.regexMatch,
    defaultSelectors: selectors,
  }).toString();

local maybeRate(expr, useRate) =
  if useRate then promql.rate({ expr: expr }) else expr;

local clampMax(expr) =
  // TODO(tsqtsq): replace with promql.clamp_max once available upstream.
  'clamp_max(%s, 1)' % expr;

// Active pod filter (Pending=1 or Running=2), normalized to 1
// pod phases are 1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown
// known issue here: https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36819
local phaseActive(phaseValues) =
  local phaseSelector = selector('k8s_pod_phase', phaseValues);
  clampMax(promql.max({
    by: podMaxBy,
    expr: promql.or({
      left: '(%s)' % promql.eq({ left: phaseSelector, right: '1' }),
      right: '(%s)' % promql.eq({ left: phaseSelector, right: '2' }),
    }),
  }));

// Joins expr against the active-pod filter: expr * on (...) group_left() ...
local activeOnly(expr, phaseValues) =
  promql.mul({
    left: expr,
    right: phaseActive(phaseValues),
    on: podMaxBy,
    groupLeft: [],
  });

{
  metricSum(metric, values, by=null, selectors=[])::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: selector(metric, values, selectors) }),
    }),

  rateSum(metric, values, by=null, selectors=[])::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: promql.rate({ expr: selector(metric, values, selectors) }) }),
    }),

  rateSumPodLevel(metric, values, by=null, selectors=[])::
    promql.sum({
      by: by,
      expr: promql.max({ by: podMaxBy, expr: promql.rate({ expr: selector(metric, values, selectors) }) }),
    }),

  rateAvg(metric, values, by=null, selectors=[])::
    promql.avg({
      by: by,
      expr: promql.max({ by: maxBy, expr: promql.rate({ expr: selector(metric, values, selectors) }) }),
    }),

  ratioSum(numeratorMetric, denominatorMetric, values, by=null, useRate=false)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: maxBy, expr: maybeRate(selector(numeratorMetric, values), useRate) }),
        right: promql.max({ by: maxBy, expr: selector(denominatorMetric, values) }),
      }),
    }),

  ratioSumPodLevel(numeratorMetric, denominatorMetric, values, by=null, useRate=false)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: podMaxBy, expr: maybeRate(selector(numeratorMetric, values), useRate) }),
        right: promql.sum({
          by: podMaxBy,
          expr: promql.max({ by: maxBy, expr: selector(denominatorMetric, values) }),
        }),
      }),
    }),

  differenceSum(metric1, metric2, values, by=null)::
    promql.sum({
      by: by,
      expr: promql.sub({
        left: promql.max({ by: maxBy, expr: selector(metric1, values) }),
        right: promql.max({ by: maxBy, expr: selector(metric2, values) }),
      }),
    }),

  metricSumActiveOnly(metric, values, phaseValues, by=null)::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: activeOnly(selector(metric, values), phaseValues) }),
    }),

  ratioSumActiveOnly(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: maxBy, expr: maybeRate(selector(numeratorMetric, values), useRate) }),
        right: promql.max({ by: maxBy, expr: activeOnly(selector(denominatorMetric, values), phaseValues) }),
      }),
    }),

  ratioSumActiveOnlyPodLevel(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: podMaxBy, expr: maybeRate(selector(numeratorMetric, values), useRate) }),
        right: '(%s)' % activeOnly(
          promql.sum({
            by: podMaxBy,
            expr: promql.max({ by: maxBy, expr: selector(denominatorMetric, values) }),
          }),
          phaseValues,
        ),
      }),
    }),
}
