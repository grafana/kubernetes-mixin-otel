local mixin = import '../mixin.libsonnet';

local exprFor(alert, config) =
  local m = mixin { _config+:: config };
  local rules = std.flattenArrays([group.rules for group in m.prometheusAlerts.groups]);
  local matching = std.filter(function(r) r.alert == alert, rules);
  assert std.length(matching) == 1 : 'expected exactly one %s rule, found %d' % [alert, std.length(matching)];
  matching[0].expr;

local conditionAlerts = [
  { alert: 'OTelKubeNodeNotReady', metric: 'k8s_node_condition_ready', comparison: '<= 0' },
  { alert: 'OTelKubeNodeMemoryPressure', metric: 'k8s_node_condition_memory_pressure', comparison: '== 1' },
  { alert: 'OTelKubeNodeDiskPressure', metric: 'k8s_node_condition_disk_pressure', comparison: '== 1' },
  { alert: 'OTelKubeNodePIDPressure', metric: 'k8s_node_condition_pid_pressure', comparison: '== 1' },
];

{
  testNodeConditionExprsHaveNoSelectorsByDefault:
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in conditionAlerts
      for expected in ['max by (k8s_cluster_name, k8s_node_name) (%s) %s' % [a.metric, a.comparison]]
      for result in [exprFor(a.alert, {})]
      if result != expected
    ];
    assert failures == [] : 'node condition exprs changed unexpectedly with no custom attributes.\n%s' % std.join('\n\n', failures);
    'PASS: all four node condition exprs unchanged when custom.attributes is unset',

  testNodeConditionExprsApplyCustomAttributes:
    local config = { custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } };
    local failures = [
      '%s expected:\n%s\n\ngot:\n%s' % [a.alert, expected, result]
      for a in conditionAlerts
      for expected in ['max by (k8s_cluster_name, k8s_node_name) (%s{env="prod"}) %s' % [a.metric, a.comparison]]
      for result in [exprFor(a.alert, config)]
      if result != expected
    ];
    assert failures == [] : 'custom.attributes not applied to every node condition alert.\n%s' % std.join('\n\n', failures);
    'PASS: custom.attributes applied to all four node condition alerts',
}
