{
  // Stat panel queries
  statQueries: {
    cpuUtilisation(config)::
      'cluster:node_cpu:ratio_rate5m{%(clusterLabel)s="$cluster"}' % config,

    cpuRequestsCommitment(config)::
      'sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % config,

    cpuLimitsCommitment(config)::
      'sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % config,

    memoryUtilisation(config)::
      '1 - sum(:node_memory_MemAvailable_bytes:sum{%(clusterLabel)s="$cluster"}) / sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s,%(clusterLabel)s="$cluster"})' % config,

    memoryRequestsCommitment(config)::
      'sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % config,

    memoryLimitsCommitment(config)::
      'sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % config,
  },

  // TimeSeries panel queries
  timeSeriesQueries: {
    cpuUsage(config)::
      'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})) by (namespace)' % config,

    memory(config)::
      'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""})) by (namespace)' % config,

    receiveBandwidth(config)::
      'sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    transmitBandwidth(config)::
      'sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    avgReceiveBandwidth(config)::
      'avg(irate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    avgTransmitBandwidth(config)::
      'avg(irate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    rateReceivedPackets(config)::
      'sum(irate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    rateTransmittedPackets(config)::
      'sum(irate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    rateReceivedPacketsDropped(config)::
      'sum(irate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    rateTransmittedPacketsDropped(config)::
      'sum(irate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

    iopsReadsWrites(config)::
      'ceil(sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s])))' % config,

    throughputReadWrite(config)::
      'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,
  },

  // Table panel queries
  tableQueries: {
    // CPU Quota table queries
    cpuQuota: {
      pods(config)::
        'sum(kube_pod_owner{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}) by (namespace)' % config,

      workloads(config)::
        'count(avg(namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster"}) by (workload, namespace)) by (namespace)' % config,

      cpuUsage(config)::
        'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})) by (namespace)' % config,

      cpuRequests(config)::
        'sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

      cpuRequestsPercent(config)::
        'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})) by (namespace) / sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

      cpuLimits(config)::
        'sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

      cpuLimitsPercent(config)::
        'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})) by (namespace) / sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,
    },

    // Memory Requests by Namespace table queries
    memoryRequests: {
      pods(config)::
        'sum(kube_pod_owner{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}) by (namespace)' % config,

      workloads(config)::
        'count(avg(namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster"}) by (workload, namespace)) by (namespace)' % config,

      memoryUsage(config)::
        'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""})) by (namespace)' % config,

      memoryRequests(config)::
        'sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

      memoryRequestsPercent(config)::
        'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""})) by (namespace) / sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

      memoryLimits(config)::
        'sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

      memoryLimitsPercent(config)::
        'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""})) by (namespace) / sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,
    },

    // Current Network Usage table queries
    networkUsage: {
      receiveBandwidth(config)::
        'sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

      transmitBandwidth(config)::
        'sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

      receivePackets(config)::
        'sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

      transmitPackets(config)::
        'sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

      receivePacketsDropped(config)::
        'sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

      transmitPacketsDropped(config)::
        'sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,
    },

    // Current Storage IO table queries
    storageIO: {
      readsIOPS(config)::
        'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

      writesIOPS(config)::
        'sum by(namespace) (rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

      totalIOPS(config)::
        'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

      readThroughput(config)::
        'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

      writeThroughput(config)::
        'sum by(namespace) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

      totalThroughput(config)::
        'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,
    },
  },
}

