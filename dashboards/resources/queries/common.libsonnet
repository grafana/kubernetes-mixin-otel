// Shared query builders for all resource dashboards, built on the tsqtsq
// jsonnet library (the same PromQL query API as the TypeScript tsqtsq).
//
// The helpers here encode this mixin's conventions -- OTel semantic
// convention labels, and de-duplication of series via max by the container
// identity labels -- expressed through the shared tsqtsq primitives.
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local containerGroupingAttributes(extra=[]) = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name', 'k8s_container_name'] + extra;
local podGroupingAttributes(extra=[]) = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name'] + extra;

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

// Merges user-supplied extraGroupingAttributes (from _config.extraGroupingAttributes)
// into an outer by(...) clause, which may otherwise be null (scalar aggregation).
local outerGroupingAttributes(by, extra=[]) =
  if by == null then
    (if extra == [] then null else extra)
  else
    by + extra;

local clampMax(expr) =
  // TODO(tsqtsq): replace with promql.clamp_max once available upstream.
  'clamp_max(%s, 1)' % expr;

// Active pod filter (Pending=1 or Running=2), normalized to 1
// pod phases are 1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown
// known issue here: https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36819
local phaseActive(phaseValues, extraAttributes=[], extraGroupingAttributes=[]) =
  local phaseSelector = selector('k8s_pod_phase', phaseValues, extraAttributes=extraAttributes);
  clampMax(promql.max({
    by: podGroupingAttributes(extraGroupingAttributes),
    expr: promql.or({
      left: '(%s)' % promql.eq({ left: phaseSelector, right: '1' }),
      right: '(%s)' % promql.eq({ left: phaseSelector, right: '2' }),
    }),
  }));

// Joins expr against the active-pod filter: expr * on (...) group_left() ...
local activeOnly(expr, phaseValues, extraAttributes=[], extraGroupingAttributes=[]) =
  promql.mul({
    left: expr,
    right: phaseActive(phaseValues, extraAttributes, extraGroupingAttributes),
    on: podGroupingAttributes(extraGroupingAttributes),
    groupLeft: [],
  });

{
  metricSum(metric, values, by=null, selectors=[], extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: selector(metric, values, selectors, extraAttributes) }),
    }),

  rateSum(metric, values, by=null, selectors=[], extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: promql.rate({ expr: selector(metric, values, selectors, extraAttributes) }) }),
    }),

  rateSumPodLevel(metric, values, by=null, selectors=[], extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.max({ by: podGroupingAttributes(extraGroupingAttributes), expr: promql.rate({ expr: selector(metric, values, selectors, extraAttributes) }) }),
    }),

  rateAvg(metric, values, by=null, selectors=[], extraAttributes=[], extraGroupingAttributes=[])::
    promql.avg({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: promql.rate({ expr: selector(metric, values, selectors, extraAttributes) }) }),
    }),

  ratioSum(numeratorMetric, denominatorMetric, values, by=null, useRate=false, extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.div({
        left: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: selector(denominatorMetric, values, extraAttributes=extraAttributes) }),
      }),
    }),

  ratioSumPodLevel(numeratorMetric, denominatorMetric, values, by=null, useRate=false, extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.div({
        left: promql.max({ by: podGroupingAttributes(extraGroupingAttributes), expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: promql.sum({
          by: podGroupingAttributes(extraGroupingAttributes),
          expr: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: selector(denominatorMetric, values, extraAttributes=extraAttributes) }),
        }),
      }),
    }),

  differenceSum(metric1, metric2, values, by=null, extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.sub({
        left: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: selector(metric1, values, extraAttributes=extraAttributes) }),
        right: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: selector(metric2, values, extraAttributes=extraAttributes) }),
      }),
    }),

  metricSumActiveOnly(metric, values, phaseValues, by=null, extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: activeOnly(selector(metric, values, extraAttributes=extraAttributes), phaseValues, extraAttributes, extraGroupingAttributes) }),
    }),

  ratioSumActiveOnly(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.div({
        left: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: activeOnly(selector(denominatorMetric, values, extraAttributes=extraAttributes), phaseValues, extraAttributes, extraGroupingAttributes) }),
      }),
    }),

  ratioSumActiveOnlyPodLevel(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, extraAttributes=[], extraGroupingAttributes=[])::
    promql.sum({
      by: outerGroupingAttributes(by, extraGroupingAttributes),
      expr: promql.div({
        left: promql.max({ by: podGroupingAttributes(extraGroupingAttributes), expr: maybeRate(selector(numeratorMetric, values, extraAttributes=extraAttributes), useRate) }),
        right: '(%s)' % activeOnly(
          promql.sum({
            by: podGroupingAttributes(extraGroupingAttributes),
            expr: promql.max({ by: containerGroupingAttributes(extraGroupingAttributes), expr: selector(denominatorMetric, values, extraAttributes=extraAttributes) }),
          }),
          phaseValues,
          extraAttributes,
          extraGroupingAttributes,
        ),
      }),
    }),
}
