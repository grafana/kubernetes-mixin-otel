// queries path must match the path in the kubernetes-mixin template
local builders = {
  // Simple metric aggregated by pod
  podMetric(metric, filters)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s{%s}
        )
      )
    ||| % [metric, filters],

  // Simple metric (total for namespace)
  namespaceMetric(metric, filters)::
    |||
      sum(
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s{%s}
        )
      )
    ||| % [metric, filters],

  // Rate metric aggregated by pod
  podRate(metric, filters)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          rate(%s{%s}[$__rate_interval])
        )
      )
    ||| % [metric, filters],

  // Rate metric aggregated by namespace
  namespaceRate(metric, filters)::
    |||
      sum by (k8s_namespace_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          rate(%s{%s}[$__rate_interval])
        )
      )
    ||| % [metric, filters],

  // Ratio of rate to metric (for utilization stats)
  namespaceUtilisation(rateMetric, denominatorMetric, filters, useRate=true)::
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
    ||| % [
      if useRate then 'rate(' else '',
      rateMetric,
      filters,
      if useRate then '[$__rate_interval])' else '',
      denominatorMetric,
      filters,
    ],

  // Ratio aggregated by pod
  podRatio(numeratorMetric, denominatorMetric, filters, useRate=false)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s%s{%s}%s
        )
        /
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s{%s}
        )
      )
    ||| % [
      if useRate then 'rate(' else '',
      numeratorMetric,
      filters,
      if useRate then '[$__rate_interval])' else '',
      denominatorMetric,
      filters,
    ],

  // Metric with active pod phase filter (Pending=1 or Running=2)
  podMetricActiveOnly(metric, filters, phaseFilters)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s{%s} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name)
          group_left() max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
            k8s_pod_phase{%s} == 1 or k8s_pod_phase{%s} == 2
          )
        )
      )
    ||| % [metric, filters, phaseFilters, phaseFilters],

  // Ratio with active pod phase filter
  podRatioActiveOnly(numeratorMetric, denominatorMetric, filters, phaseFilters, useRate=false)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s%s{%s}%s
        )
        /
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s{%s} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name)
          group_left() max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
            k8s_pod_phase{%s} == 1 or k8s_pod_phase{%s} == 2
          )
        )
      )
    ||| % [
      if useRate then 'rate(' else '',
      numeratorMetric,
      filters,
      if useRate then '[$__rate_interval])' else '',
      denominatorMetric,
      filters,
      phaseFilters,
      phaseFilters,
    ],
};

{
  local filters = 'k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"',

  // CPU Utilization Stat Queries
  cpuUtilisationFromRequests(config)::
    builders.namespaceUtilisation('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters),

  cpuUtilisationFromLimits(config)::
    builders.namespaceUtilisation('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters),

  memoryUtilisationFromRequests(config)::
    builders.namespaceUtilisation('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', filters, useRate=false),

  memoryUtilisationFromLimits(config)::
    builders.namespaceUtilisation('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', filters, useRate=false),

  // CPU Usage TimeSeries Queries
  cpuUsageByPod(config)::
    builders.podRate('k8s_pod_cpu_time_seconds_total', filters),

  cpuQuotaRequests(config)::
    '0',

  cpuQuotaLimits(config)::
    '0',

  // CPU Quota Table Queries
  cpuRequestsByPod(config)::
    builders.podMetricActiveOnly('k8s_container_cpu_request', filters, filters),

  cpuUsageVsRequests(config)::
    builders.podRatioActiveOnly('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, filters, useRate=true),

  cpuLimitsByPod(config)::
    builders.podMetricActiveOnly('k8s_container_cpu_limit', filters, filters),

  cpuUsageVsLimits(config)::
    builders.podRatioActiveOnly('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, filters, useRate=true),

  // Memory Usage TimeSeries Queries
  memoryUsageByPod(config)::
    builders.podMetric('k8s_pod_memory_working_set_bytes', filters),

  memoryQuotaRequests(config)::
    '0',

  memoryQuotaLimits(config)::
    '0',

  // Memory Quota Table Queries
  memoryRequestsByPod(config)::
    builders.podMetricActiveOnly('k8s_container_memory_request_bytes', filters, filters),

  memoryUsageVsRequests(config)::
    builders.podRatioActiveOnly('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', filters, filters),

  memoryLimitsByPod(config)::
    builders.podMetricActiveOnly('k8s_container_memory_limit_bytes', filters, filters),

  memoryUsageVsLimits(config)::
    builders.podRatioActiveOnly('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', filters, filters),

  memoryUsageRSS(config)::
    builders.podMetric('k8s_pod_memory_rss_bytes', filters),

  memoryUsageCache(config)::
    '0',

  memoryUsageSwap(config)::
    '0',

  // Network Table Queries
  networkReceiveBandwidth(config)::
    builders.namespaceRate('k8s_pod_network_io_bytes_total', filters + ', direction="receive"'),

  networkTransmitBandwidth(config)::
    builders.namespaceRate('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"'),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    builders.namespaceRate('k8s_pod_network_errors_total', filters + ', direction="receive"'),

  networkTransmitPacketsDropped(config)::
    builders.namespaceRate('k8s_pod_network_errors_total', filters + ', direction="transmit"'),

  // Network TimeSeries Queries
  networkReceiveBandwidthTimeSeries(config)::
    builders.namespaceRate('k8s_pod_network_io_bytes_total', filters + ', direction="receive"'),

  networkTransmitBandwidthTimeSeries(config)::
    builders.namespaceRate('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"'),

  rateOfReceivedPackets(config)::
    '0',

  rateOfTransmittedPackets(config)::
    '0',

  rateOfReceivedPacketsDropped(config)::
    builders.namespaceRate('k8s_pod_network_errors_total', filters + ', direction="receive"'),

  rateOfTransmittedPacketsDropped(config)::
    builders.namespaceRate('k8s_pod_network_errors_total', filters + ', direction="transmit"'),

  // Storage TimeSeries Queries
  iopsReadsWrites(config)::
    '0',

  throughputReadWrite(config)::
    '0',

  // Storage Table Queries
  storageReads(config)::
    '0',

  storageWrites(config)::
    '0',

  storageReadsPlusWrites(config)::
    '0',

  storageReadBytes(config)::
    '0',

  storageWriteBytes(config)::
    '0',

  storageReadPlusWriteBytes(config)::
    '0',
}
