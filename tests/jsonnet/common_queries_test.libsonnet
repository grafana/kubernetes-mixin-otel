local common = import '../../dashboards/resources/queries/common.libsonnet';
local mixin = import '../../mixin.libsonnet';

local values = { k8s_cluster_name: '${cluster:pipe}' };
local groupingConfig = { custom: { groupingAttributes: ['env'] } };
local baseline = 'sum by (k8s_namespace_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (metricA{k8s_cluster_name=~"${cluster:pipe}"}))';

{
  testRateAvgAppliesCustomAttributes:
    local result = common.rateAvg(
      'k8s_pod_cpu_time_seconds_total',
      {},
      config={ custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } }
    );
    local expected = 'avg(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (rate(k8s_pod_cpu_time_seconds_total{env="prod"}[$__rate_interval])))';
    assert result == expected :
           'customAttributes not applied to rateAvg.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to rateAvg',

  testRatioSumAppliesCustomAttributesToBothSides:
    local result = common.ratioSum(
      'metricA',
      'metricB',
      {},
      config={ custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } }
    );
    local expected = 'sum(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (metricA{env="prod"}) / max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (metricB{env="prod"}))';
    assert result == expected :
           'customAttributes not applied to both sides of ratioSum.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to both sides of ratioSum',

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

  testGroupingAttributesUnsetLeavesQueriesUnchanged:
    local failures = [
      'config %s produced:\n%s' % [std.toString(config), result]
      for config in [{}, { custom: {} }, { custom: { groupingAttributes: [] } }]
      for result in [common.metricSum('metricA', values, by=['k8s_namespace_name'], config=config)]
      if result != baseline
    ];
    assert failures == [] :
           'queries must be byte-identical when custom.groupingAttributes is unset.\nExpected:\n%s\n\n%s' % [baseline, std.join('\n\n', failures)];
    'PASS: queries unchanged when custom.groupingAttributes is unset or empty',

  testGroupingAttributesAppliedToMetricSum:
    local result = common.metricSum('metricA', values, by=['k8s_namespace_name'], config=groupingConfig);
    local expected = 'sum by (k8s_namespace_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricA{k8s_cluster_name=~"${cluster:pipe}"}))';
    assert result == expected :
           'groupingAttributes not applied to both aggregation levels of metricSum.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes applied to both aggregation levels of metricSum',

  testGroupingAttributesAppliedToRateAvg:
    local result = common.rateAvg('metricA', values, by=['k8s_namespace_name'], config=groupingConfig);
    local expected = 'avg by (k8s_namespace_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (rate(metricA{k8s_cluster_name=~"${cluster:pipe}"}[$__rate_interval])))';
    assert result == expected :
           'groupingAttributes not applied to both aggregation levels of rateAvg.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes applied to both aggregation levels of rateAvg',

  testGroupingAttributesAppliedToEveryLevelOfRatioSumPodLevel:
    local result = common.ratioSumPodLevel('metricA', 'metricB', values, by=['k8s_pod_name'], config=groupingConfig);
    local expected = 'sum by (k8s_pod_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, env) (metricA{k8s_cluster_name=~"${cluster:pipe}"}) / sum by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricB{k8s_cluster_name=~"${cluster:pipe}"})))';
    assert result == expected :
           'groupingAttributes missing from one of the three aggregation levels of ratioSumPodLevel; the division will match nothing.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes applied to all three aggregation levels of ratioSumPodLevel',

  testGroupingAttributesAppliedToMetricSumActiveOnly:
    local result = common.metricSumActiveOnly('metricA', values, {}, by=['k8s_namespace_name'], config=groupingConfig);
    local expected = 'sum by (k8s_namespace_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricA{k8s_cluster_name=~"${cluster:pipe}"} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) group_left() clamp_max(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) ((k8s_pod_phase{} == 1) or (k8s_pod_phase{} == 2)), 1)))';
    assert result == expected :
           'metricSumActiveOnly must group both aggregation levels and leave the active-pod join alone.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes applied to metricSumActiveOnly without touching the join',

  testGroupingAttributesAppliedToBothSidesOfDifferenceSum:
    local result = common.differenceSum('metricA', 'metricB', values, by=['k8s_namespace_name'], config=groupingConfig);
    local expected = 'sum by (k8s_namespace_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricA{k8s_cluster_name=~"${cluster:pipe}"}) - max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricB{k8s_cluster_name=~"${cluster:pipe}"}))';
    assert result == expected :
           'groupingAttributes must be applied to both sides of differenceSum or the subtraction matches nothing.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes applied to both sides of differenceSum',

  testGroupingAttributesAppliedToBothSidesOfDifferenceSumPodLevel:
    local result = common.differenceSumPodLevel('metricA', 'metricB', values, by=['k8s_pod_name'], config=groupingConfig);
    local expected = 'sum by (k8s_pod_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, env) (metricA{k8s_cluster_name=~"${cluster:pipe}"}) - max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, env) (metricB{k8s_cluster_name=~"${cluster:pipe}"}))';
    assert result == expected :
           'groupingAttributes must be applied to both sides of differenceSumPodLevel or the subtraction matches nothing.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes applied to both sides of differenceSumPodLevel',

  testGroupingAttributesAppliedToRatioSumActiveOnly:
    local result = common.ratioSumActiveOnly('metricA', 'metricB', values, {}, by=['k8s_namespace_name'], config=groupingConfig);
    local expected = 'sum by (k8s_namespace_name, env) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricA{k8s_cluster_name=~"${cluster:pipe}"}) / max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricB{k8s_cluster_name=~"${cluster:pipe}"} * on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) group_left() clamp_max(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) ((k8s_pod_phase{} == 1) or (k8s_pod_phase{} == 2)), 1)))';
    assert result == expected :
           'groupingAttributes must wrap both arms of ratioSumActiveOnly, including the max by around the activeOnly denominator.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes applied to both arms of ratioSumActiveOnly',

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

  testGroupingAttributeOrderIsDeterministic:
    local result = common.metricSum('metricA', values, by=['k8s_namespace_name'], config={ custom: { groupingAttributes: ['team', 'env'] } });
    local expected = 'sum by (k8s_namespace_name, env, team) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env, team) (metricA{k8s_cluster_name=~"${cluster:pipe}"}))';
    assert result == expected :
           'multiple groupingAttributes must render in a stable order after the existing labels.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: multiple groupingAttributes render in a stable order',

  testGroupingAttributesSkippedWhenQueryIsNotAggregated:
    local result = common.metricSum('metricA', values, config=groupingConfig);
    local expected = 'sum(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name, env) (metricA{k8s_cluster_name=~"${cluster:pipe}"}))';
    assert result == expected :
           'a builder called with by=null is a single-value stat panel and must stay unaggregated.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: groupingAttributes skipped on the outer aggregation when by is null',

  testGroupingAttributeAlreadyGroupedIsNotDuplicated:
    local result = common.metricSum('metricA', values, by=['k8s_namespace_name'], config={ custom: { groupingAttributes: ['k8s_namespace_name'] } });
    assert result == baseline :
           'a groupingAttribute the query already groups by must be deduped, not repeated.\nExpected:\n%s\n\nGot:\n%s' % [baseline, result];
    'PASS: groupingAttributes already present in the query are deduped',

  testDashboardsEvaluateWithGroupingAttributes:
    local dashboards = (mixin { _config+:: { custom+: { groupingAttributes: ['env'] } } }).grafanaDashboards;
    assert std.length(std.findSubstr(', env)', std.toString(dashboards))) > 0 :
           'custom.groupingAttributes reached no dashboard query; withGrouping has been dropped from the dashboard code path';
    'PASS: every dashboard renders with custom.groupingAttributes set',
}
