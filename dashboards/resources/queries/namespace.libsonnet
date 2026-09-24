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
    b.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', values, useRate=true, extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  cpuUtilisationFromLimits(config)::
    b.ratioSumPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', values, useRate=true, extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryUtilisationFromRequests(config)::
    b.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', values, extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryUtilisationFromLimits(config)::
    b.ratioSumPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', values, extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  // CPU Usage TimeSeries Queries
  cpuUsageByPod(config)::
    b.rateSumPodLevel('k8s_pod_cpu_time_seconds_total', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  cpuQuotaRequests(config)::
    '0',

  cpuQuotaLimits(config)::
    '0',

  // CPU Quota Table Queries
  // first query reuses cpuUsageByPod query
  cpuRequestsByPod(config)::
    b.metricSumActiveOnly('k8s_container_cpu_request', values, values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  cpuUsageVsRequests(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', values, values, by=['k8s_pod_name'], useRate=true, extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  cpuLimitsByPod(config)::
    b.metricSumActiveOnly('k8s_container_cpu_limit', values, values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  cpuUsageVsLimits(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', values, values, by=['k8s_pod_name'], useRate=true, extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  // Memory Usage TimeSeries Queries
  memoryUsageByPod(config)::
    b.metricSum('k8s_pod_memory_working_set_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryQuotaRequests(config)::
    '0',

  memoryQuotaLimits(config)::
    '0',

  // Memory Quota Table Queries
  memoryRequestsByPod(config)::
    b.metricSumActiveOnly('k8s_container_memory_request_bytes', values, values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryUsageVsRequests(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', values, values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryLimitsByPod(config)::
    b.metricSumActiveOnly('k8s_container_memory_limit_bytes', values, values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryUsageVsLimits(config)::
    b.ratioSumActiveOnlyPodLevel('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', values, values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryUsageRSS(config)::
    b.metricSum('k8s_pod_memory_rss_bytes', values, by=['k8s_pod_name'], extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  memoryUsageCache(config)::
    '0',

  memoryUsageSwap(config)::
    '0',

  // Network Table Queries
  networkReceiveBandwidth(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('receive'), extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  networkTransmitBandwidth(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('transmit'), extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    b.rateSumPodLevel('k8s_pod_network_errors_total', values, by=['k8s_namespace_name'], selectors=direction('receive'), extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  networkTransmitPacketsDropped(config)::
    b.rateSumPodLevel('k8s_pod_network_errors_total', values, by=['k8s_namespace_name'], selectors=direction('transmit'), extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  // Network TimeSeries Queries
  networkReceiveBandwidthTimeSeries(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('receive'), extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

  networkTransmitBandwidthTimeSeries(config)::
    b.rateSumPodLevel('k8s_pod_network_io_bytes_total', values, by=['k8s_namespace_name'], selectors=direction('transmit'), extraAttributes=config.extraAttributes, extraGroupingAttributes=config.extraGroupingAttributes),

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
