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

local rulesNamed(alert, config) =
  local m = mixin { _config+:: config };
  local rules = std.flattenArrays([group.rules for group in m.prometheusAlerts.groups]);
  std.filter(function(r) r.alert == alert, rules);

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

  testPodFitPodsBranchOnlyReachesSmallestPodAlert:
    local countOnly = { resourceQuotaPodFitResources: ['pods'] };
    assert rulesNamed('K8sResourceQuotaBlocksLargestPod', countOnly) == [] :
           'a pod-count quota has no largest-versus-smallest distinction, so K8sResourceQuotaBlocksLargestPod must not be emitted for it alone.';
    local defaultLargest = exprFor('K8sResourceQuotaBlocksLargestPod', {});
    assert !std.member(defaultLargest, 'resource=~"pods"') :
           'the pods branch renders identically for max and min, so emitting it on both alerts duplicates every pod-count alert.\nGot:\n%s' % defaultLargest;
    assert std.member(exprFor('K8sResourceQuotaBlocksSmallestPod', {}), 'resource=~"pods"') :
           'K8sResourceQuotaBlocksSmallestPod must keep the pods branch; it is the alert whose description matches a count quota.';
    'PASS: the aggregation-independent pods branch is emitted only on the smallest-pod alert',

  testPodFitExprsApplyCustomAttributes:
    local config = {
      resourceQuotaPodFitResources: ['requests.cpu'],
      custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
    };
    local branchMetrics = [
      'k8s_resource_quota_hard_limit',
      'k8s_resource_quota_used',
      'k8s_container_cpu_request',
      'k8s_pod_phase',
    ];
    local failures = [
      '%s: %s' % [a.alert, problem]
      for a in podFitAlerts
      for result in [exprFor(a.alert, config)]
      for problem in
        [
          '%s renders without a selector, so no matcher can reach it' % metric
          for metric in branchMetrics
          if !std.member(result, metric + '{')
        ] + [
          'filtered %d of %d selectors' % [std.length(std.findSubstr('env="prod"', result)), std.length(std.findSubstr('{', result))]
          for _ in ['once']
          if std.length(std.findSubstr('env="prod"', result)) != std.length(std.findSubstr('{', result))
        ]
    ];
    assert failures == [] :
           'custom.attributes must reach hard_limit, used, the container request metric and k8s_pod_phase; missing it on any one compares filtered data against unfiltered data. The selector-count check alone cannot see a metric that renders bare, because dropping withCustomAttributes removes the braces and the matcher together, so each expected metric is also asserted to carry a selector.\n%s' % std.join('\n', failures);
    'PASS: custom.attributes reach every selector of each pod-fit branch',

  testPodFitExprsApplyGroupingAttributes:
    local config = {
      resourceQuotaPodFitResources: ['requests.cpu'],
      custom+: { groupingAttributes: ['env'] },
    };
    local failures = [
      '%s has %d aggregations and %d grouped label lists, join carries env: %s\n%s' % [a.alert, aggregations, grouped, joinGrouped, result]
      for a in podFitAlerts
      for result in [exprFor(a.alert, config)]
      for aggregations in [std.length(std.findSubstr(' by (', result))]
      for grouped in [std.length(std.findSubstr(', env)', result))]
      for joinGrouped in [std.member(result, 'on (k8s_cluster_name, k8s_namespace_name, env)')]
      if !joinGrouped || grouped != aggregations
    ];
    assert failures == [] :
           'custom.groupingAttributes must reach every aggregation and the on() clause of the pod-fit join; reaching only one side makes the join match nothing. The counts balance because exactly one aggregation legitimately omits it (phaseActive dedups at bare pod identity) while the on() clause carries it, so a drop on either side unbalances them.\n%s' % std.join('\n\n', failures);
    'PASS: custom.groupingAttributes reach every aggregation and the pod-fit join',

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

  testPodFitDefaultCoversEverySupportedResource:
    local sizeMetrics = [
      'k8s_container_cpu_request',
      'k8s_container_memory_request_bytes',
      'k8s_container_cpu_limit',
      'k8s_container_memory_limit_bytes',
    ];
    local expectedMetrics(alert) =
      if alert == 'K8sResourceQuotaBlocksSmallestPod'
      then sizeMetrics + ['k8s_resource_quota_hard_limit{resource=~"pods"}']
      else sizeMetrics;
    local failures = [
      '%s is missing %s' % [a.alert, metric]
      for a in podFitAlerts
      for result in [exprFor(a.alert, {})]
      for metric in expectedMetrics(a.alert)
      if !std.member(result, metric)
    ];
    assert failures == [] : 'the default resource list must produce a branch per supported resource.\n%s' % std.join('\n', failures);
    'PASS: default resourceQuotaPodFitResources covers cpu and memory requests and limits, plus pods on the smallest-pod alert',
}
