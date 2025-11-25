{
  // Stat panel queries (required by template-cluster)
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

  // TimeSeries panel queries
  timeSeriesQueries: {
    cpuUsage(config)::
    'sum(
        sum by (
            k8s_cluster_name) (
                rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}"}[1m]) 
            )
        )
    )',
    memory(config)::
      'sum by (k8s_cluster_name) (
          k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}"}
      )',
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

  // Table panel queries (required by template-cluster)
  tableQueries: {
    cpuQuota: {
      pods(config):: '0',
      workloads(config):: '0',
      cpuUsage(config):: '0',
      cpuRequests(config)::
      'sum by (k8s_cluster_name, k8s_namespace_name)(
          k8s_container_cpu_request{k8s_cluster_name=~"${cluster:pipe}"}
      )',
      cpuRequestsPercent(config):: '0',
      cpuLimits(config):: '0',
      cpuLimitsPercent(config):: '0',
    },
    memoryRequests: {
      pods(config):: '0',
      workloads(config):: '0',
      memoryUsage(config):: '0',
      memoryRequests(config)::
      'sum by (k8s_cluster_name) (
          k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}"}
      )',
      memoryRequestsPercent(config):: '0',
      memoryLimits(config)::
      'sum by (k8s_cluster_name) (
          k8s_container_memory_limit_bytes{k8s_cluster_name=~"${cluster:pipe}"}
      )',
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
}

