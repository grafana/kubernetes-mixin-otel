// alerts path must match the path in the kubernetes-mixin template
{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-kubelet',
        rules: [
          {
            alert: 'KubeNodePressure',
            expr: |||
              max by (k8s_cluster_name, k8s_node_name) (k8s_node_condition_memory_pressure) == 1
              or
              max by (k8s_cluster_name, k8s_node_name) (k8s_node_condition_disk_pressure) == 1
              or
              max by (k8s_cluster_name, k8s_node_name) (k8s_node_condition_pid_pressure) == 1
            |||,
            'for': '10m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has an active MemoryPressure, DiskPressure, or PIDPressure Condition. This is caused by resource usage exceeding eviction thresholds.',
              summary: 'Node has an active pressure Condition.',
            },
          },
        ],
      },
    ],
  },
}
