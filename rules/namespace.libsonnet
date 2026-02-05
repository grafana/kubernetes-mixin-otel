{
  prometheusRules+:: {
    groups+: [
      {
        name: 'kmo.rules.pod_resources',
        rules: [
          // Pod-level CPU usage (rate of CPU time in cores) for active pods
          {
            record: 'namespace_pod:k8s_pod_cpu_time:rate5m_active',
            expr: |||
              max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                rate(k8s_pod_cpu_time_seconds_total[5m])
              ) * on (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) group_left()
              clamp_max(
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                  (k8s_pod_phase == 1) or (k8s_pod_phase == 2)
                ), 1
              )
            ||| % $._config,
          },
          // Pod-level CPU requests for active pods
          {
            record: 'namespace_pod:k8s_container_cpu_request:sum_active',
            expr: |||
              sum by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
                  k8s_container_cpu_request
                )
              ) * on (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) group_left()
              clamp_max(
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                  (k8s_pod_phase == 1) or (k8s_pod_phase == 2)
                ), 1
              )
            ||| % $._config,
          },
          // Pod-level CPU limits for active pods
          {
            record: 'namespace_pod:k8s_container_cpu_limit:sum_active',
            expr: |||
              sum by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
                  k8s_container_cpu_limit
                )
              ) * on (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) group_left()
              clamp_max(
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                  (k8s_pod_phase == 1) or (k8s_pod_phase == 2)
                ), 1
              )
            ||| % $._config,
          },
          // Pod-level memory requests for active pods
          {
            record: 'namespace_pod:k8s_container_memory_request_bytes:sum_active',
            expr: |||
              sum by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
                  k8s_container_memory_request_bytes
                )
              ) * on (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) group_left()
              clamp_max(
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                  (k8s_pod_phase == 1) or (k8s_pod_phase == 2)
                ), 1
              )
            ||| % $._config,
          },
          // Pod-level memory limits for active pods
          {
            record: 'namespace_pod:k8s_container_memory_limit_bytes:sum_active',
            expr: |||
              sum by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name, k8s_container_name) (
                  k8s_container_memory_limit_bytes
                )
              ) * on (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) group_left()
              clamp_max(
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                  (k8s_pod_phase == 1) or (k8s_pod_phase == 2)
                ), 1
              )
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
