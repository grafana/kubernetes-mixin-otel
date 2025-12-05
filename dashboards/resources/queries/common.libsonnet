// Shared query builders for all resource dashboards
local maxBy = 'k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name';
local podMaxBy = 'k8s_cluster_name, k8s_namespace_name, k8s_pod_name';

local withRate(expr, filters, useRate) =
  if useRate then
    'rate(%s{%s}[$__rate_interval])' % [expr, filters]
  else
    '%s{%s}' % [expr, filters];

local sumExpr(inner, groupBy) =
  if groupBy == '' then
    'sum(\n  %s\n)' % inner
  else
    'sum by (%s) (\n  %s\n)' % [groupBy, inner];

local maxByContainer(expr) =
  'max by (%s) (\n    %s\n  )' % [maxBy, expr];

// Active pod filter (Pending=1 or Running=2), normalized to 1
// pod phases are 1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown
// known issue here: https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/36819
local activePodFilter(phaseFilters) =
  |||
    * on (%(podMaxBy)s)
    group_left() clamp_max(
      max by (%(podMaxBy)s) (
        (k8s_pod_phase{%(filters)s} == 1) or (k8s_pod_phase{%(filters)s} == 2)
      ), 1
    )
  ||| % { podMaxBy: podMaxBy, filters: phaseFilters };

{
  metric(metric, filters, groupBy='')::
    sumExpr(
      maxByContainer('%s{%s}' % [metric, filters]),
      groupBy
    ),

  rate(metric, filters, groupBy='')::
    sumExpr(
      maxByContainer(withRate(metric, filters, true)),
      groupBy
    ),

  ratio(numeratorMetric, denominatorMetric, filters, groupBy='', useRate=false)::
    sumExpr(
      |||
        %s
        /
        %s
      ||| % [
        maxByContainer(withRate(numeratorMetric, filters, useRate)),
        maxByContainer('%s{%s}' % [denominatorMetric, filters]),
      ],
      groupBy
    ),

  difference(metric1, metric2, filters, groupBy='')::
    sumExpr(
      |||
        %s
        -
        %s
      ||| % [
        maxByContainer('%s{%s}' % [metric1, filters]),
        maxByContainer('%s{%s}' % [metric2, filters]),
      ],
      groupBy
    ),

  metricActiveOnly(metric, filters, phaseFilters, groupBy='')::
    sumExpr(
      maxByContainer('%s{%s}%s' % [metric, filters, activePodFilter(phaseFilters)]),
      groupBy
    ),

  ratioActiveOnly(numeratorMetric, denominatorMetric, filters, phaseFilters, groupBy='', useRate=false)::
    sumExpr(
      |||
        %s
        /
        %s
      ||| % [
        maxByContainer(withRate(numeratorMetric, filters, useRate)),
        maxByContainer('%s{%s}%s' % [denominatorMetric, filters, activePodFilter(phaseFilters)]),
      ],
      groupBy
    ),
}
