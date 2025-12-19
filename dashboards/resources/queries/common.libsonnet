// Shared query builders for all resource dashboards
local maxBy = 'k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name';
local podMaxBy = 'k8s_cluster_name, k8s_namespace_name, k8s_pod_name';

local withRate(expr, filters, useRate) =
  if useRate then
    'rate(%s{%s}[$__rate_interval])' % [expr, filters]
  else
    '%s{%s}' % [expr, filters];

local sumExpr(inner, by) =
  if by == '' then
    'sum(%s)' % inner
  else
    'sum by (%s) (%s)' % [by, inner];

local avgExpr(inner, by) =
  if by == '' then
    'avg(%s)' % inner
  else
    'avg by (%s) (%s)' % [by, inner];

local maxByContainer(expr) =
  'max by (%s) (%s)' % [maxBy, expr];

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
  metricSum(metric, filters, by='')::
    sumExpr(
      maxByContainer('%s{%s}' % [metric, filters]),
      by
    ),

  rateSum(metric, filters, by='')::
    sumExpr(
      maxByContainer(withRate(metric, filters, true)),
      by
    ),

  rateAvg(metric, filters, by='')::
    avgExpr(
      maxByContainer(withRate(metric, filters, true)),
      by
    ),

  ratioSum(numeratorMetric, denominatorMetric, filters, by='', useRate=false)::
    sumExpr(
      '%s / %s' % [
        maxByContainer(withRate(numeratorMetric, filters, useRate)),
        maxByContainer('%s{%s}' % [denominatorMetric, filters]),
      ],
      by
    ),

  differenceSum(metric1, metric2, filters, by='')::
    sumExpr(
      '%s - %s' % [
        maxByContainer('%s{%s}' % [metric1, filters]),
        maxByContainer('%s{%s}' % [metric2, filters]),
      ],
      by
    ),

  metricSumActiveOnly(metric, filters, phaseFilters, by='')::
    sumExpr(
      maxByContainer('%s{%s}%s' % [metric, filters, activePodFilter(phaseFilters)]),
      by
    ),

  ratioSumActiveOnly(numeratorMetric, denominatorMetric, filters, phaseFilters, by='', useRate=false)::
    sumExpr(
      '%s / %s' % [
        maxByContainer(withRate(numeratorMetric, filters, useRate)),
        maxByContainer('%s{%s}%s' % [denominatorMetric, filters, activePodFilter(phaseFilters)]),
      ],
      by
    ),
}
