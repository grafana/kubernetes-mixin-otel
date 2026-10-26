local mixin = import '../../mixin.libsonnet';

local exprFor(alert, config) =
  local m = mixin { _config+:: config };
  local rules = std.flattenArrays([group.rules for group in m.prometheusAlerts.groups]);
  local matching = std.filter(function(r) r.alert == alert, rules);
  assert std.length(matching) == 1 : 'expected exactly one %s rule, found %d' % [alert, std.length(matching)];
  matching[0].expr;

local quotaAlerts = [
  { alert: 'K8sResourceQuotaAlmostFull', comparison: '> 0.9 < 1' },
  { alert: 'K8sResourceQuotaFullyUsed', comparison: '== 1' },
  { alert: 'K8sResourceQuotaExceeded', comparison: '> 1' },
];

local ratio(by, selector) =
  'max by (%s) (k8s_resource_quota_used%s) / (max by (%s) (k8s_resource_quota_hard_limit%s) > 0)' % [by, selector, by, selector];

local defaultBy = 'k8s_cluster_name, k8s_namespace_name, k8s_resourcequota_name, resource';
local defaultPodFitBy = 'k8s_cluster_name, k8s_namespace_name';
local defaultPodMaxBy = 'k8s_cluster_name, k8s_namespace_name, k8s_pod_name';
local defaultContainerMaxBy = 'k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name';

local rulesNamed(alert, config) =
  local m = mixin { _config+:: config };
  local rules = std.flattenArrays([group.rules for group in m.prometheusAlerts.groups]);
  std.filter(function(r) r.alert == alert, rules);

local headroom(by, selector, divisor) =
  local diff = '(max by (%s) (k8s_resource_quota_hard_limit%s) > 0) - max by (%s) (k8s_resource_quota_used%s)' % [by, selector, by, selector];
  if divisor == null then '(%s) >= 0' % diff else '((%s) / %s) >= 0' % [diff, divisor];

local quotaSelector(pattern, extra) = '{resource=~"%s"%s}' % [pattern, extra];

local countBranch(by, selector) = '((%s) < 1)' % headroom(by, selector, null);

local activePodMaxBy = 'k8s_cluster_name, k8s_namespace_name, k8s_pod_name';

local activeOnly(metric, phaseSelector) =
  '%s * on (%s) group_left() clamp_max(max by (%s) ((%s == 1) or (%s == 2)), 1)' % [
    metric,
    activePodMaxBy,
    activePodMaxBy,
    phaseSelector,
    phaseSelector,
  ];

local sizeBranch(aggregation, by, selector, divisor, metric, phaseSelector, podFitBy, podMaxBy, containerMaxBy) =
  '((%s) < on (%s) group_left() %s by (%s) (sum by (%s) (max by (%s) (%s))))' % [
    headroom(by, selector, divisor),
    podFitBy,
    aggregation,
    podFitBy,
    podMaxBy,
    containerMaxBy,
    activeOnly(metric, phaseSelector),
  ];

local podFitAlerts = [
  { alert: 'K8sResourceQuotaBlocksLargestPod', aggregation: 'max' },
  { alert: 'K8sResourceQuotaBlocksSmallestPod', aggregation: 'min' },
];

{
  testQuotaExprsHaveNoSelectorsByDefault:
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in quotaAlerts
      for expected in ['%s %s' % [ratio(defaultBy, ''), a.comparison]]
      for result in [exprFor(a.alert, {})]
      if result != expected
    ];
    assert failures == [] : 'quota exprs changed unexpectedly with no custom attributes.\n%s' % std.join('\n\n', failures);
    'PASS: all three quota exprs unchanged when custom.attributes is unset',

  testQuotaExprsApplyCustomAttributes:
    local config = { custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } };
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in quotaAlerts
      for expected in ['%s %s' % [ratio(defaultBy, '{env="prod"}'), a.comparison]]
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'custom.attributes not applied to both arms of every quota alert.\n%s' % std.join('\n\n', failures);
    'PASS: custom.attributes applied to all three quota alerts',

  testQuotaAlmostFullThresholdIsConfigurable:
    local expected = '%s > 0.75 < 1' % ratio(defaultBy, '');
    local result = exprFor('K8sResourceQuotaAlmostFull', { resourceQuotaAlmostFullPercent: 75 });
    assert result == expected : 'resourceQuotaAlmostFullPercent not applied.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: resourceQuotaAlmostFullPercent overrides the almost-full threshold',

  testQuotaExprsApplyGroupingAttributes:
    local config = { custom+: { groupingAttributes: ['env'] } };
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in quotaAlerts
      for expected in ['%s %s' % [ratio(defaultBy + ', env', ''), a.comparison]]
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'custom.groupingAttributes must reach both aggregation arms or the division matches nothing.\n%s' % std.join('\n\n', failures);
    'PASS: custom.groupingAttributes applied to both arms of all three quota alerts',

  testPodFitPodsBranchComparesAgainstOnePod:
    local config = { resourceQuotaPodFitResources: ['pods'] };
    local expected = countBranch(defaultBy, quotaSelector('pods', ''));
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in podFitAlerts
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'the pods branch must compare headroom against a single pod and never join to a container metric.\n%s' % std.join('\n\n', failures);
    'PASS: pods branch is headroom < 1 with no vector join',

  testPodFitCpuBranchScalesQuotaMillicoresToCores:
    local config = { resourceQuotaPodFitResources: ['requests.cpu'] };
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in podFitAlerts
      for expected in [sizeBranch(a.aggregation, defaultBy, quotaSelector('(requests[.])?cpu', ''), '1000', 'k8s_container_cpu_request', 'k8s_pod_phase{}', defaultPodFitBy, defaultPodMaxBy, defaultContainerMaxBy)]
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'cpu quota is reported in millicores while k8s_container_cpu_request is in cores; dropping the divisor makes the comparison off by 1000.\n%s' % std.join('\n\n', failures);
    'PASS: cpu branches divide the quota side by 1000 and aggregate with max/min respectively',

  testPodFitMemoryBranchDoesNotScaleQuota:
    local config = { resourceQuotaPodFitResources: ['requests.memory'] };
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in podFitAlerts
      for expected in [sizeBranch(a.aggregation, defaultBy, quotaSelector('(requests[.])?memory', ''), null, 'k8s_container_memory_request_bytes', 'k8s_pod_phase{}', defaultPodFitBy, defaultPodMaxBy, defaultContainerMaxBy)]
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'memory quota and k8s_container_memory_request_bytes are both in bytes, so no divisor belongs here.\n%s' % std.join('\n\n', failures);
    'PASS: memory branches compare bytes to bytes with no divisor',

  testPodFitExprsApplyCustomAttributes:
    local config = {
      resourceQuotaPodFitResources: ['requests.cpu'],
      custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
    };
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in podFitAlerts
      for expected in [sizeBranch(a.aggregation, defaultBy, quotaSelector('(requests[.])?cpu', ', env="prod"'), '1000', 'k8s_container_cpu_request{env="prod"}', 'k8s_pod_phase{env="prod"}', defaultPodFitBy, defaultPodMaxBy, defaultContainerMaxBy)]
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'custom.attributes must reach the quota metrics and the container metric; missing it on either side compares unfiltered data against filtered data.\n%s' % std.join('\n\n', failures);
    'PASS: custom.attributes applied to both sides of the pod-fit join',

  testPodFitExprsApplyGroupingAttributes:
    local config = {
      resourceQuotaPodFitResources: ['requests.cpu'],
      custom+: { groupingAttributes: ['env'] },
    };
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in podFitAlerts
      for expected in [sizeBranch(
        a.aggregation,
        defaultBy + ', env',
        quotaSelector('(requests[.])?cpu', ''),
        '1000',
        'k8s_container_cpu_request',
        'k8s_pod_phase{}',
        defaultPodFitBy + ', env',
        defaultPodMaxBy + ', env',
        defaultContainerMaxBy + ', env',
      )]
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'custom.groupingAttributes must reach every aggregation level and the on() clause; reaching only one side makes the join match nothing.\n%s' % std.join('\n\n', failures);
    'PASS: custom.groupingAttributes applied to all aggregations and the on() clause',

  testPodFitAlertsAbsentWhenNoResourcesConfigured:
    local config = { resourceQuotaPodFitResources: [] };
    local failures = [
      '%s still emitted %d rule(s)' % [a.alert, std.length(found)]
      for a in podFitAlerts
      for found in [rulesNamed(a.alert, config)]
      if found != []
    ];
    assert failures == [] : 'an empty resourceQuotaPodFitResources must drop the pod-fit rules entirely, not emit an empty expr.\n%s' % std.join('\n', failures);
    'PASS: empty resourceQuotaPodFitResources removes both pod-fit alerts',

  testPodFitBranchOrderFollowsConfiguredResources:
    local config = { resourceQuotaPodFitResources: ['limits.memory', 'pods'] };
    local expected = std.join(' or ', [
      sizeBranch('max', defaultBy, quotaSelector('limits[.]memory', ''), null, 'k8s_container_memory_limit_bytes', 'k8s_pod_phase{}', defaultPodFitBy, defaultPodMaxBy, defaultContainerMaxBy),
      countBranch(defaultBy, quotaSelector('pods', '')),
    ]);
    local result = exprFor('K8sResourceQuotaBlocksLargestPod', config);
    assert result == expected : 'branch order must follow the configured resource list.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: pod-fit branches are emitted in configured order',

  testPodFitDefaultCoversEverySupportedResource:
    local expectedMetrics = [
      'k8s_resource_quota_hard_limit{resource=~"pods"}',
      'k8s_container_cpu_request',
      'k8s_container_memory_request_bytes',
      'k8s_container_cpu_limit',
      'k8s_container_memory_limit_bytes',
    ];
    local failures = [
      '%s is missing %s' % [a.alert, metric]
      for a in podFitAlerts
      for result in [exprFor(a.alert, {})]
      for metric in expectedMetrics
      if !std.member(result, metric)
    ];
    assert failures == [] : 'the default resource list must produce a branch per supported resource.\n%s' % std.join('\n', failures);
    'PASS: default resourceQuotaPodFitResources covers pods, cpu and memory requests and limits',
}
