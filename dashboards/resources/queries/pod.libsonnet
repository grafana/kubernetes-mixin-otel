// queries path must match the path in the kubernetes-mixin template
local commonQueries = import './common.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

// Dashboard variable filters, applied as regex matchers to every query.
local values = {
  k8s_cluster_name: '${cluster:pipe}',
  k8s_namespace_name: '${namespace:pipe}',
  k8s_pod_name: '${pod:pipe}',
};

local direction(value) = [
  { label: 'direction', operator: tsqtsq.MatchingOperator.equal, value: value },
];

{
  // CPU Queries
  cpuUsageByContainer(config)::
    commonQueries.rateSum('k8s_pod_cpu_time_seconds_total', values, by=['k8s_container_name'], config=config),

  cpuRequests(config)::
    commonQueries.metricSum('k8s_container_cpu_request', values, by=['k8s_pod_name'], config=config),

  cpuLimits(config)::
    commonQueries.metricSum('k8s_container_cpu_limit', values, by=['k8s_pod_name'], config=config),

  cpuThrottling(config)::
    '0',

  // CPU Quota Table Queries
  cpuRequestsByContainer(config)::
    commonQueries.metricSum('k8s_container_cpu_request', values, by=['k8s_container_name'], config=config),

  cpuUsageVsRequests(config)::
    commonQueries.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', values, by=['k8s_pod_name'], useRate=true, config=config),

  cpuLimitsByContainer(config)::
    commonQueries.metricSum('k8s_container_cpu_limit', values, by=['k8s_container_name'], config=config),

  cpuUsageVsLimits(config)::
    commonQueries.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', values, by=['k8s_pod_name'], useRate=true, config=config),

  // Memory Queries
  memoryUsageWSS(config)::
    commonQueries.metricSum('k8s_pod_memory_working_set_bytes', values, by=['k8s_pod_name'], config=config),

  memoryRequests(config)::
    commonQueries.metricSum('k8s_container_memory_request_bytes', values, by=['k8s_pod_name'], config=config),

  memoryLimits(config)::
    commonQueries.metricSum('k8s_container_memory_limit_bytes', values, by=['k8s_pod_name'], config=config),

  // Memory Quota Table Queries
  memoryRequestsByContainer(config)::
    commonQueries.metricSum('k8s_container_memory_request_bytes', values, by=['k8s_container_name'], config=config),

  memoryUsageVsRequests(config)::
    commonQueries.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', values, by=['k8s_pod_name'], config=config),

  memoryLimitsByContainer(config)::
    commonQueries.metricSum('k8s_container_memory_limit_bytes', values, by=['k8s_container_name'], config=config),

  memoryUsageVsLimits(config)::
    commonQueries.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', values, by=['k8s_pod_name'], config=config),

  memoryUsageRSS(config)::
    commonQueries.metricSum('k8s_pod_memory_rss_bytes', values, by=['k8s_pod_name'], config=config),

  memoryUsageCache(config)::
    commonQueries.differenceSum('k8s_pod_memory_usage_bytes', 'k8s_pod_memory_rss_bytes', values, by=['k8s_pod_name'], config=config),

  memoryUsageSwap(config)::
    '0',

  // Network Queries
  networkReceiveBandwidth(config)::
    commonQueries.rateSum('k8s_pod_network_io_bytes_total', values, by=['k8s_pod_name'], attributes=direction('receive'), config=config),

  networkTransmitBandwidth(config)::
    commonQueries.rateSum('k8s_pod_network_io_bytes_total', values, by=['k8s_pod_name'], attributes=direction('transmit'), config=config),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    commonQueries.rateSum('k8s_pod_network_errors_total', values, by=['k8s_pod_name'], attributes=direction('receive'), config=config),

  networkTransmitPacketsDropped(config)::
    commonQueries.rateSum('k8s_pod_network_errors_total', values, by=['k8s_pod_name'], attributes=direction('transmit'), config=config),

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
