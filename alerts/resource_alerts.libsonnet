// alerts path must match the path in the kubernetes-mixin template
local grouping = import '../lib/grouping.libsonnet';
local quota = import '../lib/resource_quota.libsonnet';
local selectors = import '../lib/selectors.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local quotaOvercommitExpr(resourcePattern, quotaDivisor, allocatableMetric, config) =
  local cluster = grouping.maybeWithGrouping(['k8s_cluster_name'], config);
  local quotaTotal = promql.sum({
    by: cluster,
    expr: promql.max({
      by: grouping.maybeWithGrouping(['k8s_cluster_name', 'k8s_namespace_name', 'k8s_resourcequota_name'], config),
      expr: selectors.selector('k8s_resource_quota_hard_limit', {}, [{ label: 'resource', operator: tsqtsq.MatchingOperator.regexMatch, value: resourcePattern }], config=config),
    }),
  });
  promql.gt({
    left: promql.div({
      left: if quotaDivisor == null then quotaTotal else promql.div({ left: quotaTotal, right: '%d' % quotaDivisor }),
      right: promql.gt({
        left: promql.sum({
          by: cluster,
          expr: promql.max({
            by: grouping.maybeWithGrouping(['k8s_cluster_name', 'k8s_node_name'], config),
            expr: selectors.withCustomAttributes(allocatableMetric, config),
          }),
        }),
        right: '0',
      }),
    }),
    right: '%g' % [config.namespaceOvercommitFactor],
  });

local quotaRatio(config) =
  local by = std.join(', ', grouping.maybeWithGrouping(quota.quotaBy, config));
  'max by (%s) (%s) / (max by (%s) (%s) > 0)' % [
    by,
    selectors.withCustomAttributes('k8s_resource_quota_used', config),
    by,
    selectors.withCustomAttributes('k8s_resource_quota_hard_limit', config),
  ];

{
  prometheusAlerts+:: {
    groups+: [
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
          {
            alert: 'K8sCPUQuotaOvercommit',
            expr: quotaOvercommitExpr('(requests[.])?cpu', 1000, 'k8s_node_allocatable_cpu', $._config),
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Cluster {{ $labels.k8s_cluster_name }} has CPU resource quota across namespaces at {{ printf "%.1f" $value }}x its allocatable CPU.',
              summary: 'Cluster has overcommitted CPU resource quota.',
            },
          },
          {
            alert: 'K8sMemoryQuotaOvercommit',
            expr: quotaOvercommitExpr('(requests[.])?memory', null, 'k8s_node_allocatable_memory_bytes', $._config),
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Cluster {{ $labels.k8s_cluster_name }} has memory resource quota across namespaces at {{ printf "%.1f" $value }}x its allocatable memory.',
              summary: 'Cluster has overcommitted memory resource quota.',
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
