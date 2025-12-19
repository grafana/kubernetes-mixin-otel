// queries path must match the path in the kubernetes-mixin template
local b = import './common.libsonnet';

{
  local filters = 'k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"',

  // CPU Queries
  cpuUsageByContainer(config)::
    b.rateSum('k8s_pod_cpu_time_seconds_total', filters, by='k8s_container_name'),

  cpuRequests(config)::
    b.metricSum('k8s_container_cpu_request', filters, by='k8s_pod_name'),

  cpuLimits(config)::
    b.metricSum('k8s_container_cpu_limit', filters, by='k8s_pod_name'),

  cpuThrottling(config)::
    '0',

  // CPU Quota Table Queries
  cpuRequestsByContainer(config)::
    b.metricSum('k8s_container_cpu_request', filters, by='k8s_container_name'),

  cpuUsageVsRequests(config)::
    b.ratioSum('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, by='k8s_pod_name', useRate=true),

  cpuLimitsByContainer(config)::
    b.metricSum('k8s_container_cpu_limit', filters, by='k8s_container_name'),

  cpuUsageVsLimits(config)::
    b.ratioSum('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, by='k8s_pod_name', useRate=true),

  // Memory Queries
  memoryUsageWSS(config)::
    b.metricSum('k8s_pod_memory_working_set_bytes', filters, by='k8s_pod_name'),

  memoryRequests(config)::
    b.metricSum('k8s_container_memory_request_bytes', filters, by='k8s_pod_name'),

  memoryLimits(config)::
    b.metricSum('k8s_container_memory_limit_bytes', filters, by='k8s_pod_name'),

  // Memory Quota Table Queries
  memoryRequestsByContainer(config)::
    b.metricSum('k8s_container_memory_request_bytes', filters, by='k8s_container_name'),

  memoryUsageVsRequests(config)::
    b.ratioSum('k8s_pod_memory_usage_bytes', 'k8s_container_memory_request_bytes', filters, by='k8s_pod_name'),

  memoryLimitsByContainer(config)::
    b.metricSum('k8s_container_memory_limit_bytes', filters, by='k8s_container_name'),

  memoryUsageVsLimits(config)::
    b.ratioSum('k8s_pod_memory_usage_bytes', 'k8s_container_memory_limit_bytes', filters, by='k8s_pod_name'),

  memoryUsageRSS(config)::
    b.metricSum('k8s_pod_memory_rss_bytes', filters, by='k8s_pod_name'),

  memoryUsageCache(config)::
    b.differenceSum('k8s_pod_memory_usage_bytes', 'k8s_pod_memory_rss_bytes', filters, by='k8s_pod_name'),

  memoryUsageSwap(config)::
    '0',

  // Network Queries
  networkReceiveBandwidth(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', filters + ', direction="receive"', by='k8s_pod_name'),

  networkTransmitBandwidth(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"', by='k8s_pod_name'),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', filters + ', direction="receive"', by='k8s_pod_name'),

  networkTransmitPacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', filters + ', direction="transmit"', by='k8s_pod_name'),

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
