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
// optional extra selectors (e.g. direction="receive") and user-supplied
// extraAttributes (from _config.extraAttributes).
local selector(metric, values, selectors=[], extraAttributes=[]) =
  tsqtsq.Expression({
    metric: metric,
    values: values,
    defaultOperator: tsqtsq.MatchingOperator.regexMatch,
    defaultSelectors: selectors + extraAttributes,
  }).toString();

local maybeRate(expr, useRate) =
  if useRate then promql.rate({ expr: expr }) else expr;

local clampMax(expr) =
  // TODO(tsqtsq): replace with promql.clamp_max once available upstream.
  'clamp_max(%s, 1)' % expr;

// Active pod filter (Pending=1 or Running=2), normalized to 1
// pod phases are 1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown
// known issue here: https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36819
local phaseActive(phaseValues, extraAttributes=[]) =
  local phaseSelector = selector('k8s_pod_phase', phaseValues, extraAttributes=extraAttributes);
  clampMax(promql.max({
    by: podMaxBy,
    expr: promql.or({
      left: '(%s)' % promql.eq({ left: phaseSelector, right: '1' }),
      right: '(%s)' % promql.eq({ left: phaseSelector, right: '2' }),
    }),
  }));

// Joins expr against the active-pod filter: expr * on (...) group_left() ...
local activeOnly(expr, phaseValues, extraAttributes=[]) =
  promql.mul({
    left: expr,
    right: phaseActive(phaseValues, extraAttributes),
    on: podMaxBy,
    groupLeft: [],
  });

{
  metricSum(metric, values, by=null, selectors=[], extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: selector(metric, values, selectors, extraAttributes) }),
    }),

  rateSum(metric, values, by=null, selectors=[], extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: promql.rate({ expr: selector(metric, values, selectors, extraAttributes) }) }),
    }),

  rateSumPodLevel(metric, values, by=null, selectors=[], extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.max({ by: podMaxBy, expr: promql.rate({ expr: selector(metric, values, selectors, extraAttributes) }) }),
    }),

  rateAvg(metric, values, by=null, selectors=[], extraAttributes=[])::
    promql.avg({
      by: by,
      expr: promql.max({ by: maxBy, expr: promql.rate({ expr: selector(metric, values, selectors, extraAttributes) }) }),
    }),

  ratioSum(numeratorMetric, denominatorMetric, values, by=null, useRate=false, extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: maxBy, expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: promql.max({ by: maxBy, expr: selector(denominatorMetric, values, extraAttributes=extraAttributes) }),
      }),
    }),

  ratioSumPodLevel(numeratorMetric, denominatorMetric, values, by=null, useRate=false, extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: podMaxBy, expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: promql.sum({
          by: podMaxBy,
          expr: promql.max({ by: maxBy, expr: selector(denominatorMetric, values, extraAttributes=extraAttributes) }),
        }),
      }),
    }),

  differenceSum(metric1, metric2, values, by=null, extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.sub({
        left: promql.max({ by: maxBy, expr: selector(metric1, values, extraAttributes=extraAttributes) }),
        right: promql.max({ by: maxBy, expr: selector(metric2, values, extraAttributes=extraAttributes) }),
      }),
    }),

  metricSumActiveOnly(metric, values, phaseValues, by=null, extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: activeOnly(selector(metric, values, extraAttributes=extraAttributes), phaseValues, extraAttributes) }),
    }),

  ratioSumActiveOnly(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: maxBy, expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: promql.max({ by: maxBy, expr: activeOnly(selector(denominatorMetric, values, extraAttributes=extraAttributes), phaseValues, extraAttributes) }),
      }),
    }),

  ratioSumActiveOnlyPodLevel(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, extraAttributes=[])::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: podMaxBy, expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: '(%s)' % activeOnly(
          promql.sum({
            by: podMaxBy,
            expr: promql.max({ by: maxBy, expr: selector(denominatorMetric, values, extraAttributes=extraAttributes) }),
          }),
          phaseValues,
          extraAttributes,
        ),
      }),
    }),
}
