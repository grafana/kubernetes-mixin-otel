// Shared query builders for all resource dashboards
{
  // Simple metric aggregated by a label
  metric(metric, filters, groupBy='')::
    if groupBy == '' then
      |||
        sum(
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
        )
      ||| % [metric, filters]
    else
      |||
        sum by (%s) (
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
        )
      ||| % [groupBy, metric, filters],

  // Rate metric aggregated by a label
  rate(metric, filters, groupBy='')::
    if groupBy == '' then
      |||
        sum(
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            rate(%s{%s}[$__rate_interval])
          )
        )
      ||| % [metric, filters]
    else
      |||
        sum by (%s) (
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            rate(%s{%s}[$__rate_interval])
          )
        )
      ||| % [groupBy, metric, filters],

  // Ratio of two metrics (optionally with rate on numerator)
  ratio(numeratorMetric, denominatorMetric, filters, groupBy='', useRate=false)::
    local ratePrefix = if useRate then 'rate(' else '';
    local rateSuffix = if useRate then '[$__rate_interval])' else '';
    if groupBy == '' then
      |||
        sum(
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s%s{%s}%s
          )
          /
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
        )
      ||| % [ratePrefix, numeratorMetric, filters, rateSuffix, denominatorMetric, filters]
    else
      |||
        sum by (%s) (
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s%s{%s}%s
          )
          /
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
        )
      ||| % [groupBy, ratePrefix, numeratorMetric, filters, rateSuffix, denominatorMetric, filters],

  // Difference of two metrics
  difference(metric1, metric2, filters, groupBy='')::
    if groupBy == '' then
      |||
        sum(
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
          -
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
        )
      ||| % [metric1, filters, metric2, filters]
    else
      |||
        sum by (%s) (
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
          -
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s}
          )
        )
      ||| % [groupBy, metric1, filters, metric2, filters],

  // Metric filtered to active pods only (Pending=1 or Running=2)
  // Uses clamp_max to normalize phase value to 1 for multiplication
  metricActiveOnly(metric, filters, phaseFilters, groupBy='')::
    if groupBy == '' then
      |||
        sum(
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name)
            group_left() clamp_max(
              max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
                (k8s_pod_phase{%s} == 1) or (k8s_pod_phase{%s} == 2)
              ), 1
            )
          )
        )
      ||| % [metric, filters, phaseFilters, phaseFilters]
    else
      |||
        sum by (%s) (
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name)
            group_left() clamp_max(
              max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
                (k8s_pod_phase{%s} == 1) or (k8s_pod_phase{%s} == 2)
              ), 1
            )
          )
        )
      ||| % [groupBy, metric, filters, phaseFilters, phaseFilters],

  // Ratio filtered to active pods only
  // Uses clamp_max to normalize phase value to 1 for multiplication
  ratioActiveOnly(numeratorMetric, denominatorMetric, filters, phaseFilters, groupBy='', useRate=false)::
    local ratePrefix = if useRate then 'rate(' else '';
    local rateSuffix = if useRate then '[$__rate_interval])' else '';
    if groupBy == '' then
      |||
        sum(
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s%s{%s}%s
          )
          /
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name)
            group_left() clamp_max(
              max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
                (k8s_pod_phase{%s} == 1) or (k8s_pod_phase{%s} == 2)
              ), 1
            )
          )
        )
      ||| % [ratePrefix, numeratorMetric, filters, rateSuffix, denominatorMetric, filters, phaseFilters, phaseFilters]
    else
      |||
        sum by (%s) (
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s%s{%s}%s
          )
          /
          max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
            %s{%s} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name)
            group_left() clamp_max(
              max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
                (k8s_pod_phase{%s} == 1) or (k8s_pod_phase{%s} == 2)
              ), 1
            )
          )
        )
      ||| % [groupBy, ratePrefix, numeratorMetric, filters, rateSuffix, denominatorMetric, filters, phaseFilters, phaseFilters],
}

