local common = import '../../dashboards/resources/queries/common.libsonnet';
local mixin = import '../../mixin.libsonnet';
local shape = import './exprshape.libsonnet';

local values = { k8s_cluster_name: '${cluster:pipe}' };
local groupingConfig = { custom: { groupingAttributes: ['env'] } };
local attributeConfig = { custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } };

local podMaxBy = ['k8s_cluster_name', 'k8s_namespace_name', 'k8s_pod_name'];
local containerMaxBy = podMaxBy + ['k8s_container_name'];

local builders(config) = {
  metricSum: common.metricSum('metricA', values, by=['k8s_namespace_name'], config=config),
  metricSumPodLevel: common.metricSumPodLevel('metricA', values, by=['k8s_pod_name'], config=config),
  rateSum: common.rateSum('metricA', values, by=['k8s_namespace_name'], config=config),
  rateSumPodLevel: common.rateSumPodLevel('metricA', values, by=['k8s_pod_name'], config=config),
  rateAvg: common.rateAvg('metricA', values, by=['k8s_namespace_name'], config=config),
  ratioSum: common.ratioSum('metricA', 'metricB', values, by=['k8s_namespace_name'], config=config),
  ratioSumPodLevel: common.ratioSumPodLevel('metricA', 'metricB', values, by=['k8s_pod_name'], config=config),
  differenceSum: common.differenceSum('metricA', 'metricB', values, by=['k8s_namespace_name'], config=config),
  differenceSumPodLevel: common.differenceSumPodLevel('metricA', 'metricB', values, by=['k8s_pod_name'], config=config),
  metricSumActiveOnly: common.metricSumActiveOnly('metricA', values, {}, by=['k8s_namespace_name'], config=config),
  ratioSumActiveOnly: common.ratioSumActiveOnly('metricA', 'metricB', values, {}, by=['k8s_namespace_name'], config=config),
  ratioSumActiveOnlyPodLevel: common.ratioSumActiveOnlyPodLevel('metricA', 'metricB', values, {}, by=['k8s_pod_name'], config=config),
};

local activeOnlyBuilders = ['metricSumActiveOnly', 'ratioSumActiveOnly', 'ratioSumActiveOnlyPodLevel'];

{
  testCustomAttributesReachEverySelector:
    local rendered = builders(attributeConfig);
    local failures = [
      '%s left %s unfiltered' % [name, selector.metric]
      for name in std.objectFields(rendered)
      for selector in shape.selectors(rendered[name])
      if !std.member(selector.matchers, 'env="prod"')
    ];
    assert failures == [] :
           'custom.attributes must reach every selector in a query; a filtered arm compared against an unfiltered one matches nothing.\n%s' % std.join('\n', failures);
    'PASS: custom.attributes reach every selector of every builder',

  testGroupingAttributesReachEveryAggregation:
    local rendered = builders(groupingConfig);
    local failures = [
      '%s aggregates by %s' % [name, std.toString(labels)]
      for name in std.objectFields(rendered)
      for labels in shape.aggregations(rendered[name])
      if !std.member(labels, 'env') && labels != podMaxBy
    ];
    assert failures == [] :
           'custom.groupingAttributes must reach every aggregation level except the active-pod phase dedup, or the division matches nothing.\n%s' % std.join('\n', failures);
    'PASS: custom.groupingAttributes reach every aggregation level',

  testGroupingAttributesStayOutOfTheActivePodJoin:
    local rendered = builders(groupingConfig);
    local failures = [
      '%s joins on %s and dedups phase by %s' % [name, std.toString(shape.joinLabels(rendered[name])), std.toString(phaseDedup)]
      for name in activeOnlyBuilders
      for phaseDedup in [[
        labels
        for labels in shape.aggregations(rendered[name])
        if labels == podMaxBy
      ]]
      if shape.joinLabels(rendered[name]) != [podMaxBy] || std.length(phaseDedup) != 1
    ];
    assert failures == [] :
           'the on() clause of activeOnly and the max by of phaseActive have to stay in lockstep at pod identity; pod identity already determines the grouping attribute, so widening a 1:1 join buys nothing and breaks it.\n%s' % std.join('\n', failures);
    'PASS: groupingAttributes stay out of the active-pod join and phase dedup',

  testDedupTupleMatchesMetricCardinality:
    local rendered = builders({});
    local containerLevel = ['metricSum', 'rateSum', 'rateAvg', 'ratioSum', 'differenceSum'];
    local failures = [
      '%s dedups by %s' % [name, std.toString(innermost)]
      for name in containerLevel
      for innermost in [shape.aggregations(rendered[name])[1]]
      if innermost != containerMaxBy
    ] + [
      '%s dedups by %s' % [name, std.toString(innermost)]
      for name in ['metricSumPodLevel', 'rateSumPodLevel', 'differenceSumPodLevel']
      for innermost in [shape.aggregations(rendered[name])[1]]
      if innermost != podMaxBy
    ];
    assert failures == [] :
           'the dedup tuple must match the cardinality of the metric: container metrics carry k8s_container_name, pod metrics do not. Deduping a pod metric with the container tuple silently multiplies it.\n%s' % std.join('\n', failures);
    'PASS: container and pod builders dedup at their own cardinality',

  testGroupingAttributesUnsetLeavesQueriesUnchanged:
    local baseline = builders({});
    local failures = [
      '%s changed under config %s' % [name, std.toString(config)]
      for config in [{ custom: {} }, { custom: { groupingAttributes: [] } }]
      for rendered in [builders(config)]
      for name in std.objectFields(baseline)
      if rendered[name] != baseline[name]
    ];
    assert failures == [] :
           'queries must be byte-identical when custom.groupingAttributes is unset or empty.\n%s' % std.join('\n', failures);
    'PASS: queries unchanged when custom.groupingAttributes is unset or empty',

  testGroupingAttributeOrderIsDeterministic:
    local result = common.metricSum('metricA', values, by=['k8s_namespace_name'], config={ custom: { groupingAttributes: ['team', 'env'] } });
    local expected = ['k8s_namespace_name', 'env', 'team'];
    assert shape.aggregations(result)[0] == expected :
           'multiple groupingAttributes must render in a stable order after the existing labels.\nExpected:\n%s\n\nGot:\n%s' % [std.toString(expected), std.toString(shape.aggregations(result)[0])];
    'PASS: multiple groupingAttributes render in a stable order',

  testGroupingAttributesSkippedWhenQueryIsNotAggregated:
    local result = common.metricSum('metricA', values, config=groupingConfig);
    local aggregations = shape.aggregations(result);
    assert std.length(aggregations) == 1 && aggregations[0] == containerMaxBy + ['env'] :
           'a builder called with by=null is a single-value stat panel and must stay unaggregated at the outer level.\nGot:\n%s' % std.toString(aggregations);
    'PASS: groupingAttributes skipped on the outer aggregation when by is null',

  testGroupingAttributeAlreadyGroupedIsNotDuplicated:
    local result = common.metricSum('metricA', values, by=['k8s_namespace_name'], config={ custom: { groupingAttributes: ['k8s_namespace_name'] } });
    local failures = [
      std.toString(labels)
      for labels in shape.aggregations(result)
      if std.length(labels) != std.length(std.set(labels))
    ];
    assert failures == [] :
           'a groupingAttribute the query already groups by must be deduped, not repeated.\n%s' % std.join('\n', failures);
    'PASS: groupingAttributes already present in the query are deduped',

  testDashboardsEvaluateWithGroupingAttributes:
    local dashboards = (mixin { _config+:: { custom+: { groupingAttributes: ['env'] } } }).grafanaDashboards;
    assert std.length(std.findSubstr(', env)', std.toString(dashboards))) > 0 :
           'custom.groupingAttributes reached no dashboard query; maybeWithGrouping has been dropped from the dashboard code path';
    'PASS: every dashboard renders with custom.groupingAttributes set',
}
