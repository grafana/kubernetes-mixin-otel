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

local resolveCustomAttributes(config) = std.get(std.get(config, 'custom', {}), 'attributes', []);

// Metric selector: dashboard variable filters (regex-matched values) plus
// optional extra attributes (e.g. direction="receive") and user-supplied
// config.custom.attributes.
local selector(metric, values, attributes=[], config) =
  local customAttributes = resolveCustomAttributes(config);
  local validOperators = std.objectValues(tsqtsq.MatchingOperator);
  local invalidOperators = std.set([attribute.operator for attribute in customAttributes if !std.member(validOperators, attribute.operator)]);
  assert invalidOperators == [] : 'custom.attributes has invalid operator(s) %s on %s, expected one of %s' % [invalidOperators, metric, validOperators];
  local equalityLabels = [attribute.label for attribute in customAttributes if attribute.operator == tsqtsq.MatchingOperator.equal];
  local duplicateLabels = [label for label in std.set(equalityLabels) if std.count(equalityLabels, label) > 1];
  assert duplicateLabels == [] : 'custom.attributes has multiple %s matchers for label(s) %s on %s' % [tsqtsq.MatchingOperator.equal, duplicateLabels, metric];
  local existingLabels = std.objectFields(values) + [attribute.label for attribute in attributes];
  local collisions = [attribute.label for attribute in customAttributes if std.member(existingLabels, attribute.label)];
  assert collisions == [] : 'custom.attributes label(s) %s collide with existing matchers on %s' % [collisions, metric];
  tsqtsq.Expression({
    metric: metric,
    values: values,
    defaultOperator: tsqtsq.MatchingOperator.regexMatch,
    defaultSelectors: attributes + customAttributes,
  }).toString();

local maybeRate(expr, useRate) =
  if useRate then promql.rate({ expr: expr }) else expr;

local clampMax(expr) =
  // TODO(tsqtsq): replace with promql.clamp_max once available upstream.
  'clamp_max(%s, 1)' % expr;

// Active pod filter (Pending=1 or Running=2), normalized to 1
// pod phases are 1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown
// known issue here: https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36819
local phaseActive(phaseValues, config) =
  local phaseSelector = selector('k8s_pod_phase', phaseValues, config=config);
  clampMax(promql.max({
    by: podMaxBy,
    expr: promql.or({
      left: '(%s)' % promql.eq({ left: phaseSelector, right: '1' }),
      right: '(%s)' % promql.eq({ left: phaseSelector, right: '2' }),
    }),
  }));

// Joins expr against the active-pod filter: expr * on (...) group_left() ...
local activeOnly(expr, phaseValues, config) =
  promql.mul({
    left: expr,
    right: phaseActive(phaseValues, config),
    on: podMaxBy,
    groupLeft: [],
  });

{
  selector:: selector,
  customAttributes:: resolveCustomAttributes,

  metricSum(metric, values, by=null, attributes=[], config)::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: selector(metric, values, attributes, config=config) }),
    }),

  rateSum(metric, values, by=null, attributes=[], config)::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: promql.rate({ expr: selector(metric, values, attributes, config=config) }) }),
    }),

  rateSumPodLevel(metric, values, by=null, attributes=[], config)::
    promql.sum({
      by: by,
      expr: promql.max({ by: podMaxBy, expr: promql.rate({ expr: selector(metric, values, attributes, config=config) }) }),
    }),

  rateAvg(metric, values, by=null, attributes=[], config)::
    promql.avg({
      by: by,
      expr: promql.max({ by: maxBy, expr: promql.rate({ expr: selector(metric, values, attributes, config=config) }) }),
    }),

  ratioSum(numeratorMetric, denominatorMetric, values, by=null, useRate=false, config)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: maxBy, expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: promql.max({ by: maxBy, expr: selector(denominatorMetric, values, config=config) }),
      }),
    }),

  ratioSumPodLevel(numeratorMetric, denominatorMetric, values, by=null, useRate=false, config)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: podMaxBy, expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: promql.sum({
          by: podMaxBy,
          expr: promql.max({ by: maxBy, expr: selector(denominatorMetric, values, config=config) }),
        }),
      }),
    }),

  differenceSum(metric1, metric2, values, by=null, config)::
    promql.sum({
      by: by,
      expr: promql.sub({
        left: promql.max({ by: maxBy, expr: selector(metric1, values, config=config) }),
        right: promql.max({ by: maxBy, expr: selector(metric2, values, config=config) }),
      }),
    }),

  metricSumActiveOnly(metric, values, phaseValues, by=null, config)::
    promql.sum({
      by: by,
      expr: promql.max({ by: maxBy, expr: activeOnly(selector(metric, values, config=config), phaseValues, config) }),
    }),

  ratioSumActiveOnly(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, config)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: maxBy, expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: promql.max({ by: maxBy, expr: activeOnly(selector(denominatorMetric, values, config=config), phaseValues, config) }),
      }),
    }),

  ratioSumActiveOnlyPodLevel(numeratorMetric, denominatorMetric, values, phaseValues, by=null, useRate=false, config)::
    promql.sum({
      by: by,
      expr: promql.div({
        left: promql.max({ by: podMaxBy, expr: maybeRate(selector(numeratorMetric, values, config=config), useRate) }),
        right: '(%s)' % activeOnly(
          promql.sum({
            by: podMaxBy,
            expr: promql.max({ by: maxBy, expr: selector(denominatorMetric, values, config=config) }),
          }),
          phaseValues,
          config,
        ),
      }),
    }),
}
