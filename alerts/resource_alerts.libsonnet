// alerts path must match the path in the kubernetes-mixin template
local selectors = import '../lib/selectors.libsonnet';

{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'k8s.policy.resource_quota',
        rules: [
          {
            alert: 'OTelKubeQuotaAlmostFull',
            expr: '%s / (%s > 0) > 0.9 < 1' % [
              selectors.withCustomAttributes('k8s_resource_quota_used', $._config),
              selectors.withCustomAttributes('k8s_resource_quota_hard_limit', $._config),
            ],
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
            expr: '%s / (%s > 0) == 1' % [
              selectors.withCustomAttributes('k8s_resource_quota_used', $._config),
              selectors.withCustomAttributes('k8s_resource_quota_hard_limit', $._config),
            ],
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
            expr: '%s / (%s > 0) > 1' % [
              selectors.withCustomAttributes('k8s_resource_quota_used', $._config),
              selectors.withCustomAttributes('k8s_resource_quota_hard_limit', $._config),
            ],
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
