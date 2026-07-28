// queries path must match the path in the kubernetes-mixin template
local b = import './common.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

// Dashboard variable filters, applied as regex matchers to every query.
local values = {
  k8s_cluster_name: '${cluster:pipe}',
  k8s_namespace_name: '${namespace:pipe}',
};

local direction(value) = [
  { label: 'direction', operator: tsqtsq.MatchingOperator.equal, value: value },
];

{
  // CPU Utilization Stat Queries
  cpuUtilisationFromRequests(config)::
    b.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', values, useRate=true),

  cpuUtilisationFromLimits(config)::
    b.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', values, useRate=true),

  memoryUtilisationFromRequests(config)::
    b.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', values),

  memoryUtilisationFromLimits(config)::
    b.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', values),

  // CPU Usage TimeSeries Queries
  cpuUsageByPod(config)::
    b.rateSumPodLevel('k8s_pod_cpu_time_seconds_total', values, by=['k8s_pod_name']),

  cpuQuotaRequests(config)::
    '0',

  cpuQuotaLimits(config)::
    '0',

  // CPU Quota Table Queries
  // first query reuses cpuUsageByPod query
  cpuRequestsByPod(config)::
    b.metricSumActiveOnly('k8s_container_cpu_request', values, values, by=['k8s_pod_name']),

  cpuUsageVsRequests(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', values, values, by=['k8s_pod_name'], useRate=true),

  cpuLimitsByPod(config)::
    b.metricSumActiveOnly('k8s_container_cpu_limit', values, values, by=['k8s_pod_name']),

  cpuUsageVsLimits(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', values, values, by=['k8s_pod_name'], useRate=true),

  // Memory Usage TimeSeries Queries
  memoryUsageByPod(config)::
    b.metricSum('k8s_pod_memory_working_set_bytes', values, by=['k8s_pod_name']),

  memoryQuotaRequests(config)::
    '0',

  memoryQuotaLimits(config)::
    '0',

  // Memory Quota Table Queries
  memoryRequestsByPod(config)::
    b.metricSumActiveOnly('k8s_container_memory_request_bytes', values, values, by=['k8s_pod_name']),

  memoryUsageVsRequests(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', values, values, by=['k8s_pod_name']),

  memoryLimitsByPod(config)::
    b.metricSumActiveOnly('k8s_container_memory_limit_bytes', values, values, by=['k8s_pod_name']),

  memoryUsageVsLimits(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', values, values, by=['k8s_pod_name']),

  memoryUsageRSS(config)::
    b.metricSum('k8s_pod_memory_rss_bytes', values, by=['k8s_pod_name']),

  memoryUsageCache(config)::
    '0',

  memoryUsageSwap(config)::
    '0',

  // Network Table Queries
  networkReceiveBandwidth(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('receive')),

  networkTransmitBandwidth(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('transmit')),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    b.rateSumPodLevel('k8s_pod_network_errors_total', values, by=['k8s_namespace_name'], selectors=direction('receive')),

  networkTransmitPacketsDropped(config)::
    b.rateSumPodLevel('k8s_pod_network_errors_total', values, by=['k8s_namespace_name'], selectors=direction('transmit')),

  // Network TimeSeries Queries
  networkReceiveBandwidthTimeSeries(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('receive')),

  networkTransmitBandwidthTimeSeries(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('transmit')),

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
