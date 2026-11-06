// alerts path must match the path in the kubernetes-mixin template
local selectors = import '../lib/selectors.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'k8s.node_component.kubelet',
        rules: [
          {
            alert: 'K8sNodeNotReady',
            expr: promql.lte({
              left: promql.max({ by: ['k8s_cluster_name', 'k8s_node_name'], expr: selectors.withCustomAttributes('k8s_node_condition_ready', $._config) }),
              right: '0',
            }),
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
            alert: 'K8sNodeMemoryPressure',
            expr: promql.eq({
              left: promql.max({ by: ['k8s_cluster_name', 'k8s_node_name'], expr: selectors.withCustomAttributes('k8s_node_condition_memory_pressure', $._config) }),
              right: '1',
            }),
            'for': '10m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has an active MemoryPressure Condition. Available memory has fallen below the eviction threshold and the kubelet may start evicting pods.',
              summary: 'Node has an active MemoryPressure Condition.',
            },
          },
          {
            alert: 'K8sNodeDiskPressure',
            expr: promql.eq({
              left: promql.max({ by: ['k8s_cluster_name', 'k8s_node_name'], expr: selectors.withCustomAttributes('k8s_node_condition_disk_pressure', $._config) }),
              right: '1',
            }),
            'for': '10m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has an active DiskPressure Condition. Available disk space or inodes have fallen below the eviction threshold; the kubelet will garbage collect images and may start evicting pods.',
              summary: 'Node has an active DiskPressure Condition.',
            },
          },
          {
            alert: 'K8sNodePIDPressure',
            expr: promql.eq({
              left: promql.max({ by: ['k8s_cluster_name', 'k8s_node_name'], expr: selectors.withCustomAttributes('k8s_node_condition_pid_pressure', $._config) }),
              right: '1',
            }),
            'for': '10m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $labels.k8s_node_name }} has an active PIDPressure Condition. The number of processes on the node is approaching the limit and the kubelet may start evicting pods.',
              summary: 'Node has an active PIDPressure Condition.',
            },
          },
          {
            alert: 'K8sNodeEviction',
            expr: promql.count({
              by: ['k8s_cluster_name', 'k8s_node_name'],
              expr: promql.unless({
                left: promql.max({
                  by: ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name', 'k8s_node_name'],
                  expr: promql.eq({ left: selectors.withCustomAttributes('k8s_pod_status_reason', $._config), right: '1' }),
                }),
                right: promql.max({
                  by: ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name'],
                  expr: promql.eq({ left: selectors.withCustomAttributes('k8s_pod_status_reason', $._config) + ' ' + promql.offset({ units: { m: 15 } }), right: '1' }),
                }),
                on: ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name'],
              }),
            }),
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Node {{ $labels.k8s_node_name }} has evicted {{ $value }} pod(s) in the last 15 minutes.',
              summary: 'Node is evicting pods.',
            },
          },
        ],
      },
    ],
  },
}
