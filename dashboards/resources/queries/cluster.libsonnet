// queries path must match the path in the kubernetes-mixin template
{
  statQueries: {
    cpuUtilisation(config)::
      '0',
    cpuRequestsCommitment(config)::
      '0',
    cpuLimitsCommitment(config)::
      '0',
    memoryUtilisation(config)::
      '0',
    memoryRequestsCommitment(config)::
      '0',
    memoryLimitsCommitment(config)::
      '0',
  },

  timeSeriesQueries: {
    cpuUsage(config)::
      'sum(\n      sum by (k8s_cluster_name) (\n        rate(\n          k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}"}\n        [$__rate_interval]) \n      )\n    )',
    memory(config)::
      'sum by (k8s_cluster_name) (\n          k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}"}\n      )',
    receiveBandwidth(config):: '0',
    transmitBandwidth(config):: '0',
    avgReceiveBandwidth(config):: '0',
    avgTransmitBandwidth(config):: '0',
    rateReceivedPackets(config):: '0',
    rateTransmittedPackets(config):: '0',
    rateReceivedPacketsDropped(config):: '0',
    rateTransmittedPacketsDropped(config):: '0',
    iopsReadsWrites(config):: '0',
    throughputReadWrite(config):: '0',
  },

  tableQueries: {
    cpuQuota: {
      pods(config):: '0',
      workloads(config):: '0',
      cpuUsage(config):: '0',
      cpuRequests(config)::
        'sum by (k8s_cluster_name, k8s_namespace_name)(\n          k8s_container_cpu_request{k8s_cluster_name=~"${cluster:pipe}"}\n      )',
      cpuRequestsPercent(config):: '0',
      cpuLimits(config):: '0',
      cpuLimitsPercent(config):: '0',
    },
    memoryRequests: {
      pods(config):: '0',
      workloads(config):: '0',
      memoryUsage(config):: '0',
      memoryRequests(config)::
        'sum by (k8s_cluster_name) (\n          k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}"}\n      )',
      memoryRequestsPercent(config):: '0',
      memoryLimits(config)::
        'sum by (k8s_cluster_name) (\n          k8s_container_memory_limit_bytes{k8s_cluster_name=~"${cluster:pipe}"}\n      )',
      memoryLimitsPercent(config):: '0',
    },
    networkUsage: {
      receiveBandwidth(config):: '0',
      transmitBandwidth(config):: '0',
      receivePackets(config):: '0',
      transmitPackets(config):: '0',
      receivePacketsDropped(config):: '0',
      transmitPacketsDropped(config):: '0',
    },
    storageIO: {
      readsIOPS(config):: '0',
      writesIOPS(config):: '0',
      totalIOPS(config):: '0',
      readThroughput(config):: '0',
      writeThroughput(config):: '0',
      totalThroughput(config):: '0',
    },
  },

  // Flat structure (for use with kubernetes-mixin template)
  // Stat queries
  cpuUtilisation(config):: self.statQueries.cpuUtilisation(config),
  cpuRequestsCommitment(config):: self.statQueries.cpuRequestsCommitment(config),
  cpuLimitsCommitment(config):: self.statQueries.cpuLimitsCommitment(config),
  memoryUtilisation(config):: self.statQueries.memoryUtilisation(config),
  memoryRequestsCommitment(config):: self.statQueries.memoryRequestsCommitment(config),
  memoryLimitsCommitment(config):: self.statQueries.memoryLimitsCommitment(config),

  // TimeSeries queries
  cpuUsageByNamespace(config):: self.timeSeriesQueries.cpuUsage(config),
  memoryUsageByNamespace(config):: self.timeSeriesQueries.memory(config),
  networkReceiveBandwidth(config):: self.timeSeriesQueries.receiveBandwidth(config),
  networkTransmitBandwidth(config):: self.timeSeriesQueries.transmitBandwidth(config),
  avgContainerReceiveBandwidth(config):: self.timeSeriesQueries.avgReceiveBandwidth(config),
  avgContainerTransmitBandwidth(config):: self.timeSeriesQueries.avgTransmitBandwidth(config),
  rateOfReceivedPackets(config):: self.timeSeriesQueries.rateReceivedPackets(config),
  rateOfTransmittedPackets(config):: self.timeSeriesQueries.rateTransmittedPackets(config),
  rateOfReceivedPacketsDropped(config):: self.timeSeriesQueries.rateReceivedPacketsDropped(config),
  rateOfTransmittedPacketsDropped(config):: self.timeSeriesQueries.rateTransmittedPacketsDropped(config),
  iopsReadsWrites(config):: self.timeSeriesQueries.iopsReadsWrites(config),
  throughputReadWrite(config):: self.timeSeriesQueries.throughputReadWrite(config),

  // Table queries
  podsByNamespace(config):: self.tableQueries.cpuQuota.pods(config),
  workloadsByNamespace(config):: self.tableQueries.cpuQuota.workloads(config),
  cpuRequestsByNamespace(config):: self.tableQueries.cpuQuota.cpuRequests(config),
  cpuUsageVsRequests(config):: self.tableQueries.cpuQuota.cpuRequestsPercent(config),
  cpuLimitsByNamespace(config):: self.tableQueries.cpuQuota.cpuLimits(config),
  cpuUsageVsLimits(config):: self.tableQueries.cpuQuota.cpuLimitsPercent(config),
  memoryRequestsByNamespace(config):: self.tableQueries.memoryRequests.memoryRequests(config),
  memoryUsageVsRequests(config):: self.tableQueries.memoryRequests.memoryRequestsPercent(config),
  memoryLimitsByNamespace(config):: self.tableQueries.memoryRequests.memoryLimits(config),
  memoryUsageVsLimits(config):: self.tableQueries.memoryRequests.memoryLimitsPercent(config),
  networkReceivePackets(config):: self.tableQueries.networkUsage.receivePackets(config),
  networkTransmitPackets(config):: self.tableQueries.networkUsage.transmitPackets(config),
  networkReceivePacketsDropped(config):: self.tableQueries.networkUsage.receivePacketsDropped(config),
  networkTransmitPacketsDropped(config):: self.tableQueries.networkUsage.transmitPacketsDropped(config),
  iopsReads(config):: self.tableQueries.storageIO.readsIOPS(config),
  iopsWrites(config):: self.tableQueries.storageIO.writesIOPS(config),
  iopsReadsWritesCombined(config):: self.tableQueries.storageIO.totalIOPS(config),
  throughputRead(config):: self.tableQueries.storageIO.readThroughput(config),
  throughputWrite(config):: self.tableQueries.storageIO.writeThroughput(config),
  throughputReadWriteCombined(config):: self.tableQueries.storageIO.totalThroughput(config),
}
