// queries path must match the path in the kubernetes-mixin template
local b = import './common.libsonnet';
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
    b.rateSum('k8s_pod_cpu_time_seconds_total', values, by=['k8s_container_name'], extraAttributes=config.extraAttributes),

  cpuRequests(config)::
    b.metricSum('k8s_container_cpu_request', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  cpuLimits(config)::
    b.metricSum('k8s_container_cpu_limit', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  cpuThrottling(config)::
    '0',

  // CPU Quota Table Queries
  cpuRequestsByContainer(config)::
    b.metricSum('k8s_container_cpu_request', values, by=['k8s_container_name'], extraAttributes=config.extraAttributes),

  cpuUsageVsRequests(config)::
    b.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', values, by=['k8s_pod_name'], useRate=true, extraAttributes=config.extraAttributes),

  cpuLimitsByContainer(config)::
    b.metricSum('k8s_container_cpu_limit', values, by=['k8s_container_name'], extraAttributes=config.extraAttributes),

  cpuUsageVsLimits(config)::
    b.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', values, by=['k8s_pod_name'], useRate=true, extraAttributes=config.extraAttributes),

  // Memory Queries
  memoryUsageWSS(config)::
    b.metricSum('k8s_pod_memory_working_set_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  memoryRequests(config)::
    b.metricSum('k8s_container_memory_request_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  memoryLimits(config)::
    b.metricSum('k8s_container_memory_limit_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  // Memory Quota Table Queries
  memoryRequestsByContainer(config)::
    b.metricSum('k8s_container_memory_request_bytes', values, by=['k8s_container_name'], extraAttributes=config.extraAttributes),

  memoryUsageVsRequests(config)::
    b.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  memoryLimitsByContainer(config)::
    b.metricSum('k8s_container_memory_limit_bytes', values, by=['k8s_container_name'], extraAttributes=config.extraAttributes),

  memoryUsageVsLimits(config)::
    b.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  memoryUsageRSS(config)::
    b.metricSum('k8s_pod_memory_rss_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  memoryUsageCache(config)::
    b.differenceSum('k8s_pod_memory_usage_bytes', 'k8s_pod_memory_rss_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes),

  memoryUsageSwap(config)::
    '0',

  // Network Queries
  networkReceiveBandwidth(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', values, by=['k8s_pod_name'], selectors=direction('receive'), extraAttributes=config.extraAttributes),

  networkTransmitBandwidth(config)::
    b.rateSum('k8s_pod_network_io_bytes_total', values, by=['k8s_pod_name'], selectors=direction('transmit'), extraAttributes=config.extraAttributes),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', values, by=['k8s_pod_name'], selectors=direction('receive'), extraAttributes=config.extraAttributes),

  networkTransmitPacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', values, by=['k8s_pod_name'], selectors=direction('transmit'), extraAttributes=config.extraAttributes),

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
