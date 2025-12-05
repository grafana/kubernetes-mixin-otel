{
  // CPU Utilization Stat Queries
  cpuUtilisationFromRequests(config)::
    |||
      sum(
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          rate(
            k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
          [$__rate_interval])
        )
        / 
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          k8s_container_cpu_request{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
        )
      )
    |||,

  cpuUtilisationFromLimits(config)::
    |||
      sum(
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          rate(
            k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
          [$__rate_interval])
        )
        / 
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          k8s_container_cpu_limit{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
        )
      )
    |||,

  memoryUtilisationFromRequests(config)::
    |||
      sum(
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
        )
        / 
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
        )
      )
    |||,

  memoryUtilisationFromLimits(config)::
    |||
      sum(
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
        )
        / 
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          k8s_container_memory_limit_bytes{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
        )
      )
    |||,

  // CPU Usage TimeSeries Queries
  cpuUsageByPod(config)::
    |||
      sum(
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, k8s_node_name) (
          rate(
            k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}
          [$__rate_interval])
        )
      ) by (pod)
    |||,

  cpuQuotaRequests(config)::
    '0',

  cpuQuotaLimits(config)::
    '0',

  // CPU Quota Table Queries
  cpuRequestsByPod(config)::
    '0',

  cpuUsageVsRequests(config)::
    '0',

  cpuLimitsByPod(config)::
    '0',

  cpuUsageVsLimits(config)::
    '0',

  // Memory Usage TimeSeries Queries
  memoryUsageByPod(config)::
    '0',

  memoryQuotaRequests(config)::
    '0',

  memoryQuotaLimits(config)::
    '0',

  // Memory Quota Table Queries
  memoryRequestsByPod(config)::
    '0',

  memoryUsageVsRequests(config)::
    '0',

  memoryLimitsByPod(config)::
    '0',

  memoryUsageVsLimits(config)::
    '0',

  memoryUsageRSS(config)::
    '0',

  memoryUsageCache(config)::
    '0',

  memoryUsageSwap(config)::
    '0',

  // Network Table Queries
  networkReceiveBandwidth(config)::
    '0',

  networkTransmitBandwidth(config)::
    '0',

  networkReceivePackets(config)::
    '0',

  networkTransmitPackets(config)::
    '0',

  networkReceivePacketsDropped(config)::
    '0',

  networkTransmitPacketsDropped(config)::
    '0',

  // Network TimeSeries Queries (using different functions - rate vs irate)
  networkReceiveBandwidthTimeSeries(config)::
    '0',

  networkTransmitBandwidthTimeSeries(config)::
    '0',

  rateOfReceivedPackets(config)::
    '0',

  rateOfTransmittedPackets(config)::
    '0',

  rateOfReceivedPacketsDropped(config)::
    '0',

  rateOfTransmittedPacketsDropped(config)::
    '0',

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
