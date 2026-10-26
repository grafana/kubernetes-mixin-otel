local common = import '../../dashboards/resources/queries/common.libsonnet';
local mixin = import '../../mixin.libsonnet';

local values = { k8s_cluster_name: '${cluster:pipe}' };
local groupingConfig = { custom: { groupingAttributes: ['env'] } };

{
  testRatioSumActiveOnlyAppliesCustomAttributesToAllArms:
    local result = common.ratioSumActiveOnly(
      'metricA',
      'metricB',
      {},
      {},
      config={ custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } }
    );
    assert std.length(std.findSubstr('env="prod"', result)) == 4 :
           'customAttributes not applied to numerator, denominator, and both active-phase join comparisons.\nGot:\n%s' % result;
    'PASS: customAttributes applied to numerator, denominator, and the active-phase join',

  testGroupingAttributesNotAddedToActivePodJoin:
    local joinClause = ' * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) group_left() ';
    local phaseDedup = 'clamp_max(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (';
    local failures = [
      'got:\n%s' % result
      for result in [
        common.metricSumActiveOnly('metricA', values, {}, by=['k8s_namespace_name'], config=groupingConfig),
        common.ratioSumActiveOnlyPodLevel('metricA', 'metricB', values, {}, by=['k8s_pod_name'], config=groupingConfig),
      ]
      if std.length(std.findSubstr(joinClause, result)) != 1 || std.length(std.findSubstr(phaseDedup, result)) != 1
    ];
    assert failures == [] :
           'groupingAttributes must stay out of the active-pod join and the phase dedup: the on list of activeOnly and the max by of phaseActive have to stay in lockstep or the join breaks outright, and pod identity already determines the grouping attribute, so widening a 1:1 join buys nothing.\n%s' % std.join('\n\n', failures);
    'PASS: groupingAttributes stay out of the active-pod join and phase dedup',

  testDashboardsEvaluateWithGroupingAttributes:
    local dashboards = (mixin { _config+:: { custom+: { groupingAttributes: ['env'] } } }).grafanaDashboards;
    assert std.length(std.findSubstr(', env)', std.toString(dashboards))) > 0 :
           'custom.groupingAttributes reached no dashboard query; maybeWithGrouping has been dropped from the dashboard code path';
    'PASS: every dashboard renders with custom.groupingAttributes set',
}
