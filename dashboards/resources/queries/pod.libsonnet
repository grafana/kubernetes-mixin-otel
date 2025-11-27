{
  // CPU Queries
  cpuUsageByContainer(config):: |||
    sum by (k8s_container_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        rate(
          k8s_pod_cpu_time_seconds_total{
            k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
          }[$__rate_interval]
        )
      )
    )
  |||,

  cpuRequests(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        k8s_pod_cpu_time_seconds_total{
          k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
        }
      )
    )
  |||,

  cpuLimits(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        k8s_container_cpu_limit{
          k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
        }
      )
    )
  |||,

  cpuThrottling(config):: '0',

  // CPU Quota Table Queries
  cpuRequestsByContainer(config):: |||
    sum by (k8s_container_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        k8s_pod_cpu_time_seconds_total{
          k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
        }
      )
    )
  |||,

  cpuUsageVsRequests(config):: '0',

  cpuLimitsByContainer(config):: |||
    sum by (k8s_container_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        k8s_container_cpu_limit{
          k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
        }
      )
    )
  |||,

  cpuUsageVsLimits(config):: '0',

  // Memory Queries
  memoryUsageWSS(config):: |||
    sum by (k8s_container_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
          k8s_pod_memory_rss_bytes{
            k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
          }
        )
    )
  |||,

  memoryRequests(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        k8s_container_memory_request_bytes{
          k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
        }
      )
    )
  |||,

  memoryLimits(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        k8s_container_memory_limit_bytes{
          k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
        }
      )
    )
  |||,

  // Memory Quota Table Queries
  memoryRequestsByContainer(config):: |||
    sum by (k8s_container_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        k8s_container_memory_request_bytes{
          k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'
        }
      )
    )
  |||,

  memoryUsageVsRequests(config):: '0',

  memoryLimitsByContainer(config):: '0',

  memoryUsageVsLimits(config):: '0',

  memoryUsageRSS(config):: '0',

  memoryUsageCache(config):: '0',

  memoryUsageSwap(config):: '0',

  // Network Queries
  networkReceiveBandwidth(config):: '0',

  networkTransmitBandwidth(config):: '0',

  networkReceivePackets(config):: '0',

  networkTransmitPackets(config):: '0',

  networkReceivePacketsDropped(config):: '0',

  networkTransmitPacketsDropped(config):: '0',

  // Storage Queries - Pod Level
  iopsPodReads(config):: '0',

  iopsPodWrites(config):: '0',

  throughputPodRead(config):: '0',

  throughputPodWrite(config):: '0',

  // Storage Queries - Container Level
  iopsContainersCombined(config):: '0',

  throughputContainersCombined(config):: '0',

  // Storage Table Queries
  storageReads(config):: '0',

  storageWrites(config):: '0',

  storageReadsPlusWrites(config):: '0',

  storageReadBytes(config):: '0',

  storageWriteBytes(config):: '0',

  storageReadPlusWriteBytes(config):: '0',
}
