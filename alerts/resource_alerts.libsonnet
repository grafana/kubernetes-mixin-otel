// alerts path must match the path in the kubernetes-mixin template
local grouping = import '../lib/grouping.libsonnet';
local selectors = import '../lib/selectors.libsonnet';

local quotaBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_resourcequota_name', 'resource'];

local quotaRatio(config) =
  local by = std.join(', ', grouping.maybeWithGrouping(quotaBy, config));
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
            alert: 'OTelKubeQuotaFullyUsed',
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
            alert: 'OTelKubeQuotaExceeded',
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
        ],
      },
    ],
  },
}
