// queries path must match the path in the kubernetes-mixin template
local b = import './common.libsonnet';

{
  local filters = 'k8s_cluster_name=~"${cluster}"',

  // CPU stat queries
  cpuUtilisation(config)::
    b.ratio('k8s_pod_cpu_time_seconds_total', 'k8s_node_allocatable_cpu_cores', filters, useRate=true),

  cpuRequestsCommitment(config)::
    b.ratio('k8s_container_cpu_request', 'k8s_node_allocatable_cpu_cores', filters),

  cpuLimitsCommitment(config)::
    b.ratio('k8s_container_cpu_limit', 'k8s_node_allocatable_cpu_cores', filters),

  // CPU usage and namespace queries
  cpuUsageByNamespace(config)::
    b.rate('k8s_pod_cpu_time_seconds_total', filters, groupBy='k8s_namespace_name'),

  podsByNamespace(config)::
    '0',

  workloadsByNamespace(config)::
    '0',

  cpuRequestsByNamespace(config)::
    b.metric('k8s_container_cpu_request', filters, groupBy='k8s_namespace_name'),

  cpuUsageVsRequests(config)::
    b.ratio('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_request', filters, groupBy='k8s_namespace_name', useRate=true),

  cpuLimitsByNamespace(config)::
    b.metric('k8s_container_cpu_limit', filters, groupBy='k8s_namespace_name'),

  cpuUsageVsLimits(config)::
    b.ratio('k8s_pod_cpu_time_seconds_total', 'k8s_container_cpu_limit', filters, groupBy='k8s_namespace_name', useRate=true),

  // Memory stat queries
  memoryUtilisation(config)::
    b.ratio('k8s_pod_memory_working_set_bytes', 'k8s_node_allocatable_memory_bytes', filters),

  memoryRequestsCommitment(config)::
    b.ratio('k8s_container_memory_request_bytes', 'k8s_node_allocatable_memory_bytes', filters),

  memoryLimitsCommitment(config)::
    b.ratio('k8s_container_memory_limit_bytes', 'k8s_node_allocatable_memory_bytes', filters),

  // Memory usage and namespace queries
  memoryUsageByNamespace(config)::
    b.metric('k8s_pod_memory_working_set_bytes', filters, groupBy='k8s_namespace_name'),

  memoryRequestsByNamespace(config)::
    b.metric('k8s_container_memory_request_bytes', filters, groupBy='k8s_namespace_name'),

  memoryUsageVsRequests(config)::
    b.ratio('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_request_bytes', filters, groupBy='k8s_namespace_name'),

  memoryLimitsByNamespace(config)::
    b.metric('k8s_container_memory_limit_bytes', filters, groupBy='k8s_namespace_name'),

  memoryUsageVsLimits(config)::
    b.ratio('k8s_pod_memory_working_set_bytes', 'k8s_container_memory_limit_bytes', filters, groupBy='k8s_namespace_name'),

  // Network queries
  networkReceiveBandwidth(config)::
    b.rate('k8s_pod_network_io_bytes_total', filters + ', direction="receive"', groupBy='k8s_namespace_name'),

  networkTransmitBandwidth(config)::
    b.rate('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"', groupBy='k8s_namespace_name'),

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    b.rate('k8s_pod_network_errors_total', filters + ', direction="receive"', groupBy='k8s_namespace_name'),

  networkTransmitPacketsDropped(config)::
    b.rate('k8s_pod_network_errors_total', filters + ', direction="transmit"', groupBy='k8s_namespace_name'),

  avgContainerReceiveBandwidth(config)::
    b.rate('k8s_pod_network_io_bytes_total', filters + ', direction="receive"', groupBy='k8s_namespace_name'),

  avgContainerTransmitBandwidth(config)::
    b.rate('k8s_pod_network_io_bytes_total', filters + ', direction="transmit"', groupBy='k8s_namespace_name'),

  rateOfReceivedPackets(config)::
    '0',

  rateOfTransmittedPackets(config)::
    '0',

  rateOfReceivedPacketsDropped(config)::
    b.rate('k8s_pod_network_errors_total', filters + ', direction="receive"', groupBy='k8s_namespace_name'),

  rateOfTransmittedPacketsDropped(config)::
    b.rate('k8s_pod_network_errors_total', filters + ', direction="transmit"', groupBy='k8s_namespace_name'),

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
