// alerts path must match the path in the kubernetes-mixin template
local activePods = import '../lib/active_pods.libsonnet';
local grouping = import '../lib/grouping.libsonnet';
local quota = import '../lib/resource_quota.libsonnet';
local selectors = import '../lib/selectors.libsonnet';

local quotaRatio(config) =
  local by = std.join(', ', grouping.maybeWithGrouping(quota.quotaBy, config));
  'max by (%s) (%s) / (max by (%s) (%s) > 0)' % [
    by,
    selectors.withCustomAttributes('k8s_resource_quota_used', config),
    by,
    selectors.withCustomAttributes('k8s_resource_quota_hard_limit', config),
  ];

local overcommitExpr(requestMetric, allocatableMetric, config) =
  local cluster = std.join(', ', grouping.maybeWithGrouping(['k8s_cluster_name'], config));
  local allocatable = selectors.withCustomAttributes(allocatableMetric, config);
  'sum by (%s) (max by (%s) (%s)) - ((sum by (%s) (max by (%s) (%s)) - max by (%s) (%s)) > 0) > 0' % [
    cluster,
    std.join(', ', grouping.maybeWithGrouping(activePods.containerMaxBy, config)),
    activePods.activeOnly(selectors.withCustomAttributes(requestMetric, config), {}, config),
    cluster,
    std.join(', ', grouping.maybeWithGrouping(['k8s_cluster_name', 'k8s_node_name'], config)),
    allocatable,
    cluster,
    allocatable,
  ];

{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'k8s.configuration.resource_management',
        rules: [
          {
            alert: 'K8sCPUOvercommit',
            expr: overcommitExpr('k8s_container_cpu_request', 'k8s_node_allocatable_cpu', $._config),
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Cluster {{ $labels.k8s_cluster_name }} has overcommitted CPU resource requests for Pods by {{ printf "%.2f" $value }} CPU cores beyond the capacity left if its largest node fails.',
              summary: 'Cluster has overcommitted CPU resource requests.',
            },
          },
          {
            alert: 'K8sMemoryOvercommit',
            expr: overcommitExpr('k8s_container_memory_request_bytes', 'k8s_node_allocatable_memory_bytes', $._config),
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Cluster {{ $labels.k8s_cluster_name }} has overcommitted memory resource requests for Pods by {{ $value | humanize }}B beyond the capacity left if its largest node fails.',
              summary: 'Cluster has overcommitted memory resource requests.',
            },
          },
          {
            alert: 'K8sContainerMemoryNearLimit',
            expr: 'max by (%s) (%s) > %g' % [
              std.join(', ', grouping.maybeWithGrouping(activePods.containerMaxBy, $._config)),
              selectors.withCustomAttributes('k8s_container_memory_limit_utilization_ratio', $._config),
              $._config.containerMemoryNearLimitPercent / 100,
            ],
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Container {{ $labels.k8s_container_name }} in pod {{ $labels.k8s_pod_name }} (namespace {{ $labels.k8s_namespace_name }}) is using {{ $value | humanizePercentage }} of its memory limit.',
              summary: 'Container memory usage is close to its limit.',
            },
          },
          {
            alert: 'K8sContainerCPUNearLimit',
            expr: 'max by (%s) (%s) > %g' % [
              std.join(', ', grouping.maybeWithGrouping(activePods.containerMaxBy, $._config)),
              selectors.withCustomAttributes('k8s_container_cpu_limit_utilization_ratio', $._config),
              $._config.containerCPUNearLimitPercent / 100,
            ],
            'for': '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Container {{ $labels.k8s_container_name }} in pod {{ $labels.k8s_pod_name }} (namespace {{ $labels.k8s_namespace_name }}) is using {{ $value | humanizePercentage }} of its CPU limit.',
              summary: 'Container CPU usage is close to its limit.',
            },
          },
        ],
      },
      {
        name: 'k8s.policy.resource_quota',
        rules: [
          {
            alert: 'K8sResourceQuotaAlmostFull',
            expr: '%s > %g < 1' % [quotaRatio($._config), $._config.resourceQuotaAlmostFullPercent / 100],
            'for': '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.',
              summary: 'Namespace quota is going to be full.',
            },
          },
          {
            alert: 'K8sResourceQuotaFullyUsed',
            expr: '%s == 1' % quotaRatio($._config),
            'for': '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.',
              summary: 'Namespace quota is fully used.',
            },
          },
          {
            alert: 'K8sResourceQuotaExceeded',
            expr: '%s > 1' % quotaRatio($._config),
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.',
              summary: 'Namespace quota has exceeded the limits.',
            },
          },
        ] + (
          if quota.resolvePodFitResources('max', $._config) == [] then [] else [
            {
              alert: 'K8sResourceQuotaBlocksLargestPod',
              expr: quota.podFitExpr('max', $._config),
              'for': '15m',
              labels: {
                severity: 'info',
              },
              annotations: {
                description: 'ResourceQuota {{ $labels.k8s_resourcequota_name }} in namespace {{ $labels.k8s_namespace_name }} has less {{ $labels.resource }} headroom ({{ $value | humanize }}) than its largest pod needs, so another pod that size cannot be scheduled.',
                summary: 'Namespace quota cannot fit another large replica pod.',
              },
            },
          ]
        ) + (
          if quota.resolvePodFitResources('min', $._config) == [] then [] else [
            {
              alert: 'K8sResourceQuotaBlocksSmallestPod',
              expr: quota.podFitExpr('min', $._config),
              'for': '15m',
              labels: {
                severity: 'warning',
              },
              annotations: {
                description: 'ResourceQuota {{ $labels.k8s_resourcequota_name }} in namespace {{ $labels.k8s_namespace_name }} has less {{ $labels.resource }} headroom ({{ $value | humanize }}) than its smallest pod needs, so no further pod can be scheduled.',
                summary: 'Namespace quota cannot fit any additional replica pod.',
              },
            },
          ]
        ),
      },
    ],
  },
}
