// queries path must match the path in the kubernetes-mixin template
local b = import './common.libsonnet';

{
  local filters = 'k8s_cluster_name=~"${cluster:pipe}"',

  // CPU stat queries
  cpuUtilisation(config)::
    b.ratioSum('k8s_pod_cpu_time_seconds_total', 'system_cpu_logical_count', filters, useRate=true),

  cpuRequestsCommitment(config)::
    b.ratioSum('k8s_container_cpu_request', 'k8s_node_allocatable_cpu_cores', filters),

  cpuLimitsCommitment(config)::
    b.ratioSum('k8s_container_cpu_limit', 'k8s_node_allocatable_cpu_cores', filters),

  // CPU usage and namespace queries
  cpuUsageByNamespace(config)::
    b.rateSum('k8s_pod_cpu_time_seconds_total', filters, by='k8s_namespace_name'),

  podsByNamespace(config)::
    '0',

  workloadsByNamespace(config)::
    '0',

  cpuRequestsByNamespace(config)::
    b.metricSum('k8s_container_cpu_request', filters, by='k8s_namespace_name'),

  cpuUsageVsRequests(config)::
    b.ratioSum('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, by='k8s_namespace_name', useRate=true),

  cpuLimitsByNamespace(config)::
    b.metricSum('k8s_container_cpu_limit', filters, by='k8s_namespace_name'),

  cpuUsageVsLimits(config)::
    b.ratioSum('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, by='k8s_namespace_name', useRate=true),

  // Memory stat queries
  memoryUtilisation(config)::
    b.ratioSum('k8s_pod_memory_working_set_bytes', 'k8s_node_allocatable_memory_bytes', filters),

  memoryRequestsCommitment(config)::
    b.ratioSum('k8s_container_memory_request_bytes', 'k8s_node_allocatable_memory_bytes', filters),

  memoryLimitsCommitment(config)::
    b.ratioSum('k8s_container_memory_limit_bytes', 'k8s_node_allocatable_memory_bytes', filters),

  // Memory usage and namespace queries
  memoryUsageByNamespace(config)::
    b.metricSum('k8s_pod_memory_working_set_bytes', filters, by='k8s_namespace_name'),

  memoryRequestsByNamespace(config)::
    b.metricSum('k8s_container_memory_request_bytes', filters, by='k8s_namespace_name'),

  memoryUsageVsRequests(config)::
    b.ratioSum('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', filters, by='k8s_namespace_name'),

  memoryLimitsByNamespace(config)::
    b.metricSum('k8s_container_memory_limit_bytes', filters, by='k8s_namespace_name'),

  memoryUsageVsLimits(config)::
    b.ratioSum('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', filters, by='k8s_namespace_name'),

  // Network queries
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

  avgContainerReceiveBandwidth(config)::
    b.rateAvg('k8s_pod_network_io_bytes_total', filters + ', direction="receive"', by='k8s_namespace_name'),

  avgContainerTransmitBandwidth(config)::
    b.rateAvg('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"', by='k8s_namespace_name'),

  rateOfReceivedPackets(config)::
    '0',

  rateOfTransmittedPackets(config)::
    '0',

  rateOfReceivedPacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', filters + ', direction="receive"', by='k8s_namespace_name'),

  rateOfTransmittedPacketsDropped(config)::
    b.rateSum('k8s_pod_network_errors_total', filters + ', direction="transmit"', by='k8s_namespace_name'),

  // Storage I/O queries
  iopsReadsWrites(config)::
    '0',

  throughputReadWrite(config)::
    '0',

  iopsReads(config)::
    '0',

  iopsWrites(config)::
    '0',

  iopsReadsWritesCombined(config)::
    '0',

  throughputRead(config)::
    '0',

  throughputWrite(config)::
    '0',

  throughputReadWriteCombined(config)::
    '0',
}
