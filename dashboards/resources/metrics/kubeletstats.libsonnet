// Metrics from kubeletstats receiver
// These come from the kubelet stats API and represent actual resource usage
{
  // CPU usage metrics
  podCpuTimeSecondsTotal(filters):: |||
    k8s_pod_cpu_time_seconds_total{%s}
  ||| % filters,

  // Memory usage metrics
  podMemoryWorkingSetBytes(filters):: |||
    k8s_pod_memory_working_set_bytes{%s}
  ||| % filters,

  podMemoryUsageBytes(filters):: |||
    k8s_pod_memory_usage_bytes{%s}
  ||| % filters,

  podMemoryRssBytes(filters):: |||
    k8s_pod_memory_rss_bytes{%s}
  ||| % filters,

  podMemorySwapBytes(filters):: |||
    k8s_pod_memory_swap_bytes{%s}
  ||| % filters,

  // Network metrics
  podNetworkIoBytesTotal(filters, direction):: |||
    k8s_pod_network_io_bytes_total{%s, direction="%s"}
  ||| % [filters, direction],

  podNetworkIoTotal(filters, direction):: |||
    k8s_pod_network_io_total{%s, direction="%s"}
  ||| % [filters, direction],

  podNetworkErrorsTotal(filters, direction):: |||
    k8s_pod_network_errors_total{%s, direction="%s"}
  ||| % [filters, direction],

  // Filesystem metrics
  podFilesystemIoTotal(filters, direction):: |||
    k8s_pod_filesystem_io_total{%s, direction="%s"}
  ||| % [filters, direction],

  podFilesystemIoBytesTotal(filters, direction):: |||
    k8s_pod_filesystem_io_bytes_total{%s, direction="%s"}
  ||| % [filters, direction],

  // Container-level filesystem metrics
  containerFilesystemIoTotal(filters, direction):: |||
    k8s_container_filesystem_io_total{%s, direction="%s"}
  ||| % [filters, direction],

  containerFilesystemIoBytesTotal(filters, direction):: |||
    k8s_container_filesystem_io_bytes_total{%s, direction="%s"}
  ||| % [filters, direction],

  // CPU throttling metrics
  containerCpuCfsThrottledPeriodsTotal(filters):: |||
    k8s_container_cpu_cfs_throttled_periods_total{%s}
  ||| % filters,

  containerCpuCfsPeriodsTotal(filters):: |||
    k8s_container_cpu_cfs_periods_total{%s}
  ||| % filters,
}

