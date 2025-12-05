// queries path must match the path in the kubernetes-mixin template
local b = import './common.libsonnet';

{
  local filters = 'k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}", k8s_pod_name=~"${pod}"',

  // CPU Queries
  cpuUsageByContainer(config)::
    b.rate('k8s_pod_cpu_time_seconds_total', filters, groupBy='k8s_container_name'),

  cpuRequests(config)::
    b.metric('k8s_container_cpu_request', filters, groupBy='k8s_pod_name'),

  cpuLimits(config)::
    b.metric('k8s_container_cpu_limit', filters, groupBy='k8s_pod_name'),

  cpuThrottling(config)::
    '0',

  // CPU Quota Table Queries
  cpuRequestsByContainer(config)::
    b.metric('k8s_container_cpu_request', filters, groupBy='k8s_container_name'),

  cpuUsageVsRequests(config)::
    b.ratio('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, groupBy='k8s_pod_name', useRate=true),

  cpuLimitsByContainer(config)::
    b.metric('k8s_container_cpu_limit', filters, groupBy='k8s_container_name'),

  cpuUsageVsLimits(config)::
    b.ratio('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, groupBy='k8s_pod_name', useRate=true),

  // Memory Queries
  memoryUsageWSS(config)::
    b.metric('k8s_pod_memory_working_set_bytes', filters, groupBy='k8s_pod_name'),

  memoryRequests(config)::
    b.metric('k8s_container_memory_request_bytes', filters, groupBy='k8s_pod_name'),

  memoryLimits(config)::
    b.metric('k8s_container_memory_limit_bytes', filters, groupBy='k8s_pod_name'),

  // Memory Quota Table Queries
  memoryRequestsByContainer(config)::
    b.metric('k8s_container_memory_request_bytes', filters, groupBy='k8s_container_name'),

  memoryUsageVsRequests(config)::
    b.ratio('k8s_pod_memory_usage_bytes', 'k8s_container_memory_request_bytes', filters, groupBy='k8s_pod_name'),

  memoryLimitsByContainer(config)::
    b.metric('k8s_container_memory_limit_bytes', filters, groupBy='k8s_container_name'),

  memoryUsageVsLimits(config)::
    b.ratio('k8s_pod_memory_usage_bytes', 'k8s_container_memory_limit_bytes', filters, groupBy='k8s_pod_name'),

  memoryUsageRSS(config)::
    b.metric('k8s_pod_memory_rss_bytes', filters, groupBy='k8s_pod_name'),

  memoryUsageCache(config)::
    b.difference('k8s_pod_memory_usage_bytes', 'k8s_pod_memory_rss_bytes', filters, groupBy='k8s_pod_name'),

  memoryUsageSwap(config)::
    '0',

  // Network Queries
  networkReceiveBandwidth(config)::
    b.rate('k8s_pod_network_io_bytes_total', filters + ', direction="receive"', groupBy='k8s_pod_name'),

  networkTransmitBandwidth(config)::
    b.rate('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"', groupBy='k8s_pod_name'),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    b.rate('k8s_pod_network_errors_total', filters + ', direction="receive"', groupBy='k8s_pod_name'),

  networkTransmitPacketsDropped(config)::
    b.rate('k8s_pod_network_errors_total', filters + ', direction="transmit"', groupBy='k8s_pod_name'),

  // Storage Queries - Pod Level
  iopsPodReads(config)::
    '0',

  iopsPodWrites(config)::
    '0',

  throughputPodRead(config)::
    '0',

  throughputPodWrite(config)::
    '0',

  // Storage Queries - Container Level
  iopsContainersCombined(config)::
    '0',

  throughputContainersCombined(config)::
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
