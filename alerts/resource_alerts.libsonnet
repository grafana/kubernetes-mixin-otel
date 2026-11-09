// alerts path must match the path in the kubernetes-mixin template
local activePods = import '../lib/active_pods.libsonnet';
local grouping = import '../lib/grouping.libsonnet';
local quota = import '../lib/resource_quota.libsonnet';
local selectors = import '../lib/selectors.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local quotaOvercommitExpr(resourcePattern, quotaDivisor, allocatableMetric, config) =
  local cluster = grouping.maybeWithGrouping(['k8s_cluster_name'], config);
  local quotaTotal = promql.sum({
    by: cluster,
    expr: promql.min({
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
    right: '%g' % [config.resourceQuotaTotalOvercommitFactor],
  });

local quotaRatio(config) =
  local by = grouping.maybeWithGrouping(quota.quotaBy, config);
  promql.div({
    left: promql.max({ by: by, expr: selectors.withCustomAttributes('k8s_resource_quota_used', config) }),
    right: promql.gt({
      left: promql.max({ by: by, expr: selectors.withCustomAttributes('k8s_resource_quota_hard_limit', config) }),
      right: '0',
    }),
  });

local overcommitExpr(requestMetric, allocatableMetric, config) =
  local cluster = grouping.maybeWithGrouping(['k8s_cluster_name'], config);
  local allocatable = selectors.withCustomAttributes(allocatableMetric, config);
  local requests = promql.sum({
    by: cluster,
    expr: promql.max({
      by: grouping.maybeWithGrouping(activePods.containerMaxBy, config),
      expr: activePods.activeOnly(selectors.withCustomAttributes(requestMetric, config), {}, config),
    }),
  });
  local capacityWithoutLargestNode = promql.sub({
    left: promql.sum({
      by: cluster,
      expr: promql.max({
        by: grouping.maybeWithGrouping(['k8s_cluster_name', 'k8s_node_name'], config),
        expr: allocatable,
      }),
    }),
    right: promql.max({ by: cluster, expr: allocatable }),
  });
  promql.and({
    left: promql.gt({ left: promql.sub({ left: requests, right: capacityWithoutLargestNode }), right: '0' }),
    right: promql.gt({ left: capacityWithoutLargestNode, right: '0' }),
  });

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
            expr: promql.gt({
              left: promql.div({
                left: promql.max({
                  by: grouping.maybeWithGrouping(activePods.containerMaxBy, $._config),
                  expr: selectors.withCustomAttributes('container_memory_working_set_bytes', $._config),
                }),
                right: promql.gt({
                  left: promql.max({
                    by: grouping.maybeWithGrouping(activePods.containerMaxBy, $._config),
                    expr: selectors.withCustomAttributes('k8s_container_memory_limit_bytes', $._config),
                  }),
                  right: '0',
                }),
              }),
              right: '%g' % [$._config.containerMemoryNearLimitPercent / 100],
            }),
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
            alert: 'K8sContainerOOMKilled',
            expr: promql.max({
              by: ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name', 'k8s_container_name'],
              expr: promql.unless({
                left: selectors.selector('target_info', {}, [{ label: 'k8s_container_status_last_terminated_reason', operator: tsqtsq.MatchingOperator.equal, value: 'OOMKilled' }], config=$._config),
                right: selectors.selector('target_info', {}, [{ label: 'k8s_container_status_last_terminated_reason', operator: tsqtsq.MatchingOperator.equal, value: 'OOMKilled' }], config=$._config) + ' ' + promql.offset({ units: { m: 15 } }),
                on: ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name', 'k8s_container_name', 'container_id'],
              }),
            }),
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Container {{ $labels.k8s_container_name }} in pod {{ $labels.k8s_pod_name }} (namespace {{ $labels.k8s_namespace_name }}) restarted after being OOM-killed in the last 15 minutes.',
              summary: 'Container was OOM-killed.',
            },
          },
        ],
      },
      {
        name: 'k8s.policy.resource_quota',
        rules: [
          {
            alert: 'K8sResourceQuotaAlmostFull',
            expr: promql.lt({
              left: promql.gt({ left: quotaRatio($._config), right: '%g' % [$._config.resourceQuotaAlmostFullPercent / 100] }),
              right: '1',
            }),
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
            expr: promql.eq({ left: quotaRatio($._config), right: '1' }),
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
            expr: promql.gt({ left: quotaRatio($._config), right: '1' }),
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
            expr: quotaOvercommitExpr('cpu|requests[.]cpu', 1000, 'k8s_node_allocatable_cpu', $._config),
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
            expr: quotaOvercommitExpr('memory|requests[.]memory', null, 'k8s_node_allocatable_memory_bytes', $._config),
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
