// queries path must match the path in the kubernetes-mixin template
{
  // CPU stat queries
  cpuUtilisation(config):: '0',
  cpuRequestsCommitment(config):: '0',
  cpuLimitsCommitment(config):: '0',

  // CPU usage and namespace queries
  cpuUsageByNamespace(config):: |||
    sum(
      sum by (k8s_cluster_name, k8s_namespace_name) (
        rate(
          k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}"}[$__rate_interval]
        )
      )
    )
  |||,

  podsByNamespace(config):: '0',
  workloadsByNamespace(config):: '0',
  cpuRequestsByNamespace(config):: '0',
  cpuUsageVsRequests(config):: '0',
  cpuLimitsByNamespace(config):: '0',
  cpuUsageVsLimits(config):: '0',

  // Memory stat queries
  memoryUtilisation(config):: '0',
  memoryRequestsCommitment(config):: '0',
  memoryLimitsCommitment(config):: '0',

  // Memory usage and namespace queries
  memoryUsageByNamespace(config):: |||
    sum by (k8s_cluster_name, k8s_namespace_name) (
      k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}"}
    )
  |||,

  memoryRequestsByNamespace(config):: '0',
  memoryUsageVsRequests(config):: '0',
  memoryLimitsByNamespace(config):: '0',
  memoryUsageVsLimits(config):: '0',

  // Network queries
  networkReceiveBandwidth(config):: '0',
  networkTransmitBandwidth(config):: '0',
  networkReceivePackets(config):: '0',
  networkTransmitPackets(config):: '0',
  networkReceivePacketsDropped(config):: '0',
  networkTransmitPacketsDropped(config):: '0',
  avgContainerReceiveBandwidth(config):: '0',
  avgContainerTransmitBandwidth(config):: '0',
  rateOfReceivedPackets(config):: '0',
  rateOfTransmittedPackets(config):: '0',
  rateOfReceivedPacketsDropped(config):: '0',
  rateOfTransmittedPacketsDropped(config):: '0',

  // Storage I/O queries
  iopsReadsWrites(config):: '0',
  throughputReadWrite(config):: '0',
  iopsReads(config):: '0',
  iopsWrites(config):: '0',
  iopsReadsWritesCombined(config):: '0',
  throughputRead(config):: '0',
  throughputWrite(config):: '0',
  throughputReadWriteCombined(config):: '0',
}
