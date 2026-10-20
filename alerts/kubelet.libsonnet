// alerts path must match the path in the kubernetes-mixin template
local selectors = import '../lib/selectors.libsonnet';

{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-kubelet',
        rules: [
          {
            alert: 'KubeNodeNotReady',
            expr: 'max by (k8s_cluster_name, k8s_node_name) (%s) <= 0' % selectors.withCustomAttributes('k8s_node_condition_ready', $._config),
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has been unready for more than 15 minutes.',
              summary: 'Node is not ready.',
            },
          },
          {
            alert: 'KubeNodeMemoryPressure',
            expr: 'max by (k8s_cluster_name, k8s_node_name) (%s) == 1' % selectors.withCustomAttributes('k8s_node_condition_memory_pressure', $._config),
            'for': '10m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has an active MemoryPressure Condition. Available memory has fallen below the eviction threshold and the kubelet may start evicting pods.',
              summary: 'Node has an active MemoryPressure Condition.',
              runbook_url: $._config.runbookURLPattern % 'kubenodepressure',
            },
          },
          {
            alert: 'KubeNodeDiskPressure',
            expr: 'max by (k8s_cluster_name, k8s_node_name) (%s) == 1' % selectors.withCustomAttributes('k8s_node_condition_disk_pressure', $._config),
            'for': '10m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has an active DiskPressure Condition. Available disk space or inodes have fallen below the eviction threshold; the kubelet will garbage collect images and may start evicting pods.',
              summary: 'Node has an active DiskPressure Condition.',
              runbook_url: $._config.runbookURLPattern % 'kubenodepressure',
            },
          },
          {
            alert: 'KubeNodePIDPressure',
            expr: 'max by (k8s_cluster_name, k8s_node_name) (%s) == 1' % selectors.withCustomAttributes('k8s_node_condition_pid_pressure', $._config),
            'for': '10m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has an active PIDPressure Condition. The number of processes on the node is approaching the limit and the kubelet may start evicting pods.',
              summary: 'Node has an active PIDPressure Condition.',
              runbook_url: $._config.runbookURLPattern % 'kubenodepressure',
            },
          },
        ],
      },
    ],
  },
}
