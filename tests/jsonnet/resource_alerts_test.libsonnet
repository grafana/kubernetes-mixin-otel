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
}
