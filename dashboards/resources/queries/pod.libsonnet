// queries path must match the path in the kubernetes-mixin template
local builders = {
  podMetric(metric, filters)::
    |||
      sum by (k8s_pod_name) (
        max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
          %s{%s}
        )
      )
    ||| % [metric, filters],

  containerMetric(metric, filters)::
    |||
      sum by (k8s_container_name) (
        max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          %s{%s}
        )
      )
    ||| % [metric, filters],

  podRate(metric, filters)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
          rate(%s{%s}[$__rate_interval])
        )
      )
    ||| % [metric, filters],

  containerRate(metric, filters)::
    |||
      sum by (k8s_container_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          rate(%s{%s}[$__rate_interval])
        )
      )
    ||| % [metric, filters],

  ratio(numeratorMetric, denominatorMetric, filters, useRate=false)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
          %s%s{%s}%s
        )
        /
        max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
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

  difference(metric1, metric2, filters)::
    |||
      sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (%s{%s})
        -
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (%s{%s})
      )
    ||| % [metric1, filters, metric2, filters],
};

{
  local filters = "k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'",

  // CPU Queries
  cpuUsageByContainer(config)::
    builders.containerRate('k8s_pod_cpu_time_seconds_total', filters),

  cpuRequests(config)::
    builders.podMetric('k8s_container_cpu_request', filters),

  cpuLimits(config)::
    builders.podMetric('k8s_container_cpu_limit', filters),

  cpuThrottling(config):: '0',

  // CPU Quota Table Queries
  cpuRequestsByContainer(config)::
    builders.containerMetric('k8s_container_cpu_request', filters),

  cpuUsageVsRequests(config)::
    builders.ratio('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, useRate=true),

  cpuLimitsByContainer(config)::
    builders.containerMetric('k8s_container_cpu_limit', filters),

  cpuUsageVsLimits(config)::
    builders.ratio('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, useRate=true),

  // Memory Queries
  memoryUsageWSS(config)::
    builders.podMetric('k8s_pod_memory_working_set_bytes', filters),

  memoryRequests(config)::
    builders.podMetric('k8s_container_memory_request_bytes', filters),

  memoryLimits(config)::
    builders.podMetric('k8s_container_memory_limit_bytes', filters),

  // Memory Quota Table Queries
  memoryRequestsByContainer(config)::
    builders.containerMetric('k8s_container_memory_request_bytes', filters),

  memoryUsageVsRequests(config)::
    builders.ratio('k8s_pod_memory_usage_bytes', 'k8s_container_memory_request_bytes', filters),

  memoryLimitsByContainer(config)::
    builders.containerMetric('k8s_container_memory_limit_bytes', filters),

  memoryUsageVsLimits(config)::
    builders.ratio('k8s_pod_memory_usage_bytes', 'k8s_container_memory_limit_bytes', filters),

  memoryUsageRSS(config)::
    builders.podMetric('k8s_pod_memory_rss_bytes', filters),

  memoryUsageCache(config)::
    builders.difference(
      'k8s_pod_memory_usage_bytes',
      'k8s_pod_memory_rss_bytes',
      filters
    ),

  memoryUsageSwap(config):: '0',

  // Network Queries
  networkReceiveBandwidth(config)::
    builders.podRate('k8s_pod_network_io_bytes_total', filters + ', direction="receive"'),

  networkTransmitBandwidth(config)::
    builders.podRate('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"'),

  networkReceivePackets(config):: '0',

  networkTransmitPackets(config):: '0',

  networkReceivePacketsDropped(config)::
    builders.podRate('k8s_pod_network_errors_total', filters + ', direction="receive"'),

  networkTransmitPacketsDropped(config)::
    builders.podRate('k8s_pod_network_errors_total', filters + ', direction="transmit"'),

  // Storage Queries - Pod Level
  iopsPodReads(config):: '0',

  iopsPodWrites(config):: '0',

  throughputPodRead(config):: '0',

  throughputPodWrite(config):: '0',

  // Storage Queries - Container Level
  iopsContainersCombined(config):: '0',

  throughputContainersCombined(config):: '0',

  // Storage Table Queries
  storageReads(config):: '0',

  storageWrites(config):: '0',

  storageReadsPlusWrites(config):: '0',

  storageReadBytes(config):: '0',

  storageWriteBytes(config):: '0',

  storageReadPlusWriteBytes(config):: '0',
}
