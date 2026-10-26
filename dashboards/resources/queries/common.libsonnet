// Shared query builders for all resource dashboards, built on the tsqtsq
// jsonnet library (the same PromQL query API as the TypeScript tsqtsq).
//
// The helpers here encode this mixin's conventions -- OTel semantic
// convention labels, and de-duplication of series via max by the container or
// pod identity labels -- expressed through the shared tsqtsq primitives.
local activePods = import '../../../lib/active_pods.libsonnet';
local grouping = import '../../../lib/grouping.libsonnet';
local selectors = import '../../../lib/selectors.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local maxBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name', 'k8s_container_name'];
local podMaxBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name'];

local selector = selectors.selector;
local maybeWithGrouping = grouping.maybeWithGrouping;

local maybeRate(expr, useRate) =
  if useRate then promql.rate({ expr: expr }) else expr;

local activeOnly = activePods.activeOnly;

{
  metricSum(metric, values, by=null, attributes=[], config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.max({ by: maybeWithGrouping(maxBy, config), expr: selector(metric, values, attributes, config=config) }),
    }),

  metricSumPodLevel(metric, values, by=null, attributes=[], config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.max({ by: maybeWithGrouping(podMaxBy, config), expr: selector(metric, values, attributes, config=config) }),
    }),

  rateSum(metric, values, by=null, attributes=[], config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.max({ by: maybeWithGrouping(maxBy, config), expr: promql.rate({ expr: selector(metric, values, attributes, config=config) }) }),
    }),

  rateSumPodLevel(metric, values, by=null, attributes=[], config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.max({ by: maybeWithGrouping(podMaxBy, config), expr: promql.rate({ expr: selector(metric, values, attributes, config=config) }) }),
    }),

  rateAvg(metric, values, by=null, attributes=[], config)::
    promql.avg({
      by: maybeWithGrouping(by, config),
      expr: promql.max({ by: maybeWithGrouping(maxBy, config), expr: promql.rate({ expr: selector(metric, values, attributes, config=config) }) }),
    }),

  ratioSum(numeratorMetric, denominatorMetric, values, by=null, useRate=false, config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.div({
        left: promql.max({ by: maybeWithGrouping(maxBy, config), expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: promql.max({ by: maybeWithGrouping(maxBy, config), expr: selector(denominatorMetric, values, config=config) }),
      }),
    }),

  ratioSumPodLevel(numeratorMetric, denominatorMetric, values, by=null, useRate=false, config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.div({
        left: promql.max({ by: maybeWithGrouping(podMaxBy, config), expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: promql.sum({
          by: maybeWithGrouping(podMaxBy, config),
          expr: promql.max({ by: maybeWithGrouping(maxBy, config), expr: selector(denominatorMetric, values, config=config) }),
        }),
      }),
    }),

  differenceSum(metric1, metric2, values, by=null, config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.sub({
        left: promql.max({ by: maybeWithGrouping(maxBy, config), expr: selector(metric1, values, config=config) }),
        right: promql.max({ by: maybeWithGrouping(maxBy, config), expr: selector(metric2, values, config=config) }),
      }),
    }),

  differenceSumPodLevel(metric1, metric2, values, by=null, config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.sub({
        left: promql.max({ by: maybeWithGrouping(podMaxBy, config), expr: selector(metric1, values, config=config) }),
        right: promql.max({ by: maybeWithGrouping(podMaxBy, config), expr: selector(metric2, values, config=config) }),
      }),
    }),

  metricSumActiveOnly(metric, values, phaseValues, by=null, config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.max({ by: maybeWithGrouping(maxBy, config), expr: activeOnly(selector(metric, values, config=config), phaseValues, config) }),
    }),

  ratioSumActiveOnly(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.div({
        left: promql.max({ by: maybeWithGrouping(maxBy, config), expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: promql.max({ by: maybeWithGrouping(maxBy, config), expr: activeOnly(selector(denominatorMetric, values, config=config), phaseValues, config) }),
      }),
    }),

  ratioSumActiveOnlyPodLevel(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, config)::
    promql.sum({
      by: maybeWithGrouping(by, config),
      expr: promql.div({
        left: promql.max({ by: maybeWithGrouping(podMaxBy, config), expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: activeOnly(
          promql.sum({
            by: maybeWithGrouping(podMaxBy, config),
            expr: promql.max({ by: maybeWithGrouping(maxBy, config), expr: selector(denominatorMetric, values, config=config) }),
          }),
          phaseValues,
          config,
        ),
      }),
    }),
}
