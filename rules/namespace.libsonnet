{
  _config+:: {
    clusterLabel: 'k8s_cluster_name',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'otel.k8s.rules.namespace_cpu_requests',
        rules: [
          {
            // CPU requests for active pods (Pending or Running) by pod, summed from containers
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
        ],
      },
      {
        name: 'otel.k8s.rules.namespace_cpu_usage_vs_requests',
        rules: [
          {
            // CPU usage rate vs requests ratio for active pods
            record: 'namespace_pod:k8s_pod_cpu_usage_vs_request:ratio_rate5m',
            expr: |||
              sum by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                  rate(k8s_pod_cpu_time_seconds_total[5m])
                )
                /
                (
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
                )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'otel.k8s.rules.namespace_cpu_limits',
        rules: [
          {
            // CPU limits for active pods (Pending or Running) by pod, summed from containers
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
        ],
      },
      {
        name: 'otel.k8s.rules.namespace_cpu_usage_vs_limits',
        rules: [
          {
            // CPU usage rate vs limits ratio for active pods
            record: 'namespace_pod:k8s_pod_cpu_usage_vs_limit:ratio_rate5m',
            expr: |||
              sum by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                max by (%(clusterLabel)s, k8s_namespace_name, k8s_pod_name) (
                  rate(k8s_pod_cpu_time_seconds_total[5m])
                )
                /
                (
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
                )
              )
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
