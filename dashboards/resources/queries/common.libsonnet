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

local maxExpr(inner, by) =
  'max by (%s) (%s)' % [by, inner];

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
      maxExpr('%s{%s}' % [metric, filters], maxBy),
      by
    ),

  rateSum(metric, filters, by='')::
    sumExpr(
      maxExpr(withRate(metric, filters, true), maxBy),
      by
    ),

  rateSumPodLevel(metric, filters, by='')::
    sumExpr(
      maxExpr(withRate(metric, filters, true), podMaxBy),
      by
    ),

  rateAvg(metric, filters, by='')::
    avgExpr(
      maxExpr(withRate(metric, filters, true), maxBy),
      by
    ),

  ratioSum(numeratorMetric, denominatorMetric, filters, by='', useRate=false)::
    sumExpr(
      '%s / %s' % [
        maxExpr(withRate(numeratorMetric, filters, useRate), maxBy),
        maxExpr('%s{%s}' % [denominatorMetric, filters], maxBy),
      ],
      by
    ),

  ratioSumPodLevel(numeratorMetric, denominatorMetric, filters, by='', useRate=false)::
    sumExpr(
      '%s / %s' % [
        maxExpr(withRate(numeratorMetric, filters, useRate), podMaxBy),
        sumExpr(maxExpr('%s{%s}' % [denominatorMetric, filters], maxBy), podMaxBy),
      ],
      by
    ),

  differenceSum(metric1, metric2, filters, by='')::
    sumExpr(
      '%s - %s' % [
        maxExpr('%s{%s}' % [metric1, filters], maxBy),
        maxExpr('%s{%s}' % [metric2, filters], maxBy),
      ],
      by
    ),

  metricSumActiveOnly(metric, filters, phaseFilters, by='')::
    '%s%s' % [
      sumExpr(
        maxExpr('%s{%s}' % [metric, filters], maxBy),
        by
      ),
      activePodFilter(phaseFilters),
    ],

  ratioSumActiveOnly(numeratorMetric, denominatorMetric, filters, phaseFilters, by='', useRate=false)::
    sumExpr(
      '%s / (%s%s)' % [
        maxExpr(withRate(numeratorMetric, filters, useRate), maxBy),
        maxExpr('%s{%s}' % [denominatorMetric, filters], maxBy),
        activePodFilter(phaseFilters),
      ],
      by
    ),

  ratioSumActiveOnlyPodLevel(numeratorMetric, denominatorMetric, filters, phaseFilters, by='', useRate=false)::
    sumExpr(
      '%s / (%s%s)' % [
        maxExpr(withRate(numeratorMetric, filters, useRate), podMaxBy),
        sumExpr(maxExpr('%s{%s}' % [denominatorMetric, filters], maxBy), podMaxBy),
        activePodFilter(phaseFilters),
      ],
      by
    ),
}
