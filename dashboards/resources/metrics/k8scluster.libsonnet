// Metrics from k8scluster receiver (equivalent to kube-state-metrics)
// These come from the Kubernetes API and represent desired resource configurations
{
  // CPU resource specifications
  containerCpuRequest(filters):: |||
    k8s_container_cpu_request{%s}
  ||| % filters,

  containerCpuLimit(filters):: |||
    k8s_container_cpu_limit{%s}
  ||| % filters,

  // Memory resource specifications
  containerMemoryRequestBytes(filters):: |||
    k8s_container_memory_request_bytes{%s}
  ||| % filters,

  containerMemoryLimitBytes(filters):: |||
    k8s_container_memory_limit_bytes{%s}
  ||| % filters,
}
