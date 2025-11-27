local k8scluster = import '../metrics/k8scluster.libsonnet';
local kubeletstats = import '../metrics/kubeletstats.libsonnet';

// queries path must match the path in the kubernetes-mixin template
{
  local filters = "k8s_cluster_name=~'${cluster}', k8s_namespace_name=~'${namespace}', k8s_pod_name=~'${pod}'",

  // CPU Queries
  cpuUsageByContainer(config):: |||
    sum by (k8s_container_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        rate(
          %s[$__rate_interval]
        )
      )
    )
  ||| % kubeletstats.podCpuTimeSecondsTotal(filters),

  cpuRequests(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        %s
      )
    )
  ||| % k8scluster.containerCpuRequest(filters),

  cpuLimits(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        %s
      )
    )
  ||| % k8scluster.containerCpuLimit(filters),

  cpuThrottling(config):: '0',

  // CPU Quota Table Queries
  cpuRequestsByContainer(config):: |||
    sum by (k8s_container_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        %s
      )
    )
  ||| % k8scluster.containerCpuRequest(filters),

  cpuUsageVsRequests(config):: |||
    sum by (k8s_pod_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        rate(
          %s[$__rate_interval]
        )
      )
    )
    /
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
    )
  ||| % [kubeletstats.podCpuTimeSecondsTotal(filters), k8scluster.containerCpuRequest(filters)],

  cpuLimitsByContainer(config):: |||
    sum by (k8s_container_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        %s
      )
    )
  ||| % k8scluster.containerCpuLimit(filters),

  cpuUsageVsLimits(config):: |||
    sum by (k8s_pod_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        rate(
          %s[$__rate_interval]
        )
      )
    )
    /
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
    )
  ||| % [kubeletstats.podCpuTimeSecondsTotal(filters), k8scluster.containerCpuLimit(filters)],

  // Memory Queries
  memoryUsageWSS(config):: |||
    sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
          %s
        )
    )
  ||| % kubeletstats.podMemoryWorkingSetBytes(filters),

  memoryRequests(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
    )
  ||| % k8scluster.containerMemoryRequestBytes(filters),

  memoryLimits(config):: |||
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
    )
  ||| % k8scluster.containerMemoryLimitBytes(filters),

  // Memory Quota Table Queries
  memoryRequestsByContainer(config):: |||
    sum by (k8s_container_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        %s
      )
    )
  ||| % k8scluster.containerMemoryRequestBytes(filters),

  memoryUsageVsRequests(config):: |||
    sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
          %s
        )
    )
    /
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
    )
  ||| % [kubeletstats.podMemoryUsageBytes(filters), k8scluster.containerMemoryRequestBytes(filters)],

  memoryLimitsByContainer(config):: |||
    sum by (k8s_container_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
        %s
      )
    )
  ||| % k8scluster.containerMemoryLimitBytes(filters),

  memoryUsageVsLimits(config):: |||
    sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
          %s
        )
    )
    /
    sum by (k8s_pod_name) (
      max by(k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
    )
  ||| % [kubeletstats.podMemoryUsageBytes(filters), k8scluster.containerMemoryLimitBytes(filters)],

  memoryUsageRSS(config):: |||
    sum by (k8s_pod_name) (
        max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
          %s
        )
    )
  ||| % kubeletstats.podMemoryRssBytes(filters),

  memoryUsageCache(config):: |||
    sum by (k8s_pod_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
      -
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        %s
      )
    )
  ||| % [kubeletstats.podMemoryUsageBytes(filters), kubeletstats.podMemoryRssBytes(filters)],

  memoryUsageSwap(config):: '0',

  // Network Queries
  networkReceiveBandwidth(config):: |||
    sum by (k8s_pod_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        rate(
          %s[$__rate_interval]
        )
      )
    )
  ||| % kubeletstats.podNetworkIoBytesTotal(filters, 'receive'),

  networkTransmitBandwidth(config):: |||
    sum by (k8s_pod_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        rate(
          %s[$__rate_interval]
        )
      )
    )
  ||| % kubeletstats.podNetworkIoBytesTotal(filters, 'transmit'),

  networkReceivePackets(config):: '0',

  networkTransmitPackets(config):: '0',

  networkReceivePacketsDropped(config):: |||
    sum by (k8s_pod_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        rate(
          %s[$__rate_interval]
        )
      )
    )
  ||| % kubeletstats.podNetworkErrorsTotal(filters, 'receive'),

  networkTransmitPacketsDropped(config):: |||
    sum by (k8s_pod_name) (
      max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (
        rate(
          %s[$__rate_interval]
        )
      )
    )
  ||| % kubeletstats.podNetworkErrorsTotal(filters, 'transmit'),

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
