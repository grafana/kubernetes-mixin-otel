// queries path must match the path in the kubernetes-mixin template
local b = import './common.libsonnet';

{
  local filters = 'k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"',

  // CPU Utilization Stat Queries
  cpuUtilisationFromRequests(config)::
    b.ratioSum('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, useRate=true),

  cpuUtilisationFromLimits(config)::
    b.ratioSum('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, useRate=true),

  memoryUtilisationFromRequests(config)::
    b.ratioSum('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', filters),

  memoryUtilisationFromLimits(config)::
    b.ratioSum('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', filters),

  // CPU Usage TimeSeries Queries
  cpuUsageByPod(config)::
    b.rateSum('k8s_pod_cpu_time_seconds_total', filters, by='k8s_pod_name'),

  cpuQuotaRequests(config)::
    '0',

  cpuQuotaLimits(config)::
    '0',

  // CPU Quota Table Queries
  cpuRequestsByPod(config)::
    b.metricSumActiveOnly('k8s_container_cpu_request', filters, filters, by='k8s_pod_name'),

  cpuUsageVsRequests(config)::
    b.ratioSumActiveOnly('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, filters, by='k8s_pod_name', useRate=true),

  cpuLimitsByPod(config)::
    b.metricSumActiveOnly('k8s_container_cpu_limit', filters, filters, by='k8s_pod_name'),

  cpuUsageVsLimits(config)::
    b.ratioSumActiveOnly('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, filters, by='k8s_pod_name', useRate=true),

  // Memory Usage TimeSeries Queries
  memoryUsageByPod(config)::
    b.metricSum('k8s_pod_memory_working_set_bytes', filters, by='k8s_pod_name'),

  memoryQuotaRequests(config)::
    '0',

  memoryQuotaLimits(config)::
    '0',

  // Memory Quota Table Queries
  memoryRequestsByPod(config)::
    b.metricSumActiveOnly('k8s_container_memory_request_bytes', filters, filters, by='k8s_pod_name'),

  memoryUsageVsRequests(config)::
    b.ratioSumActiveOnly('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', filters, filters, by='k8s_pod_name'),

  memoryLimitsByPod(config)::
    b.metricSumActiveOnly('k8s_container_memory_limit_bytes', filters, filters, by='k8s_pod_name'),

  memoryUsageVsLimits(config)::
    b.ratioSumActiveOnly('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', filters, filters, by='k8s_pod_name'),

  memoryUsageRSS(config)::
    b.metricSum('k8s_pod_memory_rss_bytes', filters, by='k8s_pod_name'),

  memoryUsageCache(config)::
    '0',

  memoryUsageSwap(config)::
    '0',

  // Network Table Queries
  networkReceiveBandwidth(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', filters + ', direction="receive"', by='k8s_namespace_name'),

  networkTransmitBandwidth(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"', by='k8s_namespace_name'),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', filters + ', direction="receive"', by='k8s_namespace_name'),

  networkTransmitPacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', filters + ', direction="transmit"', by='k8s_namespace_name'),

  // Network TimeSeries Queries
  networkReceiveBandwidthTimeSeries(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', filters + ', direction="receive"', by='k8s_namespace_name'),

  networkTransmitBandwidthTimeSeries(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"', by='k8s_namespace_name'),

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
