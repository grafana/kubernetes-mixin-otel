local grouping = import '../../lib/grouping.libsonnet';

local by = ['k8s_cluster_name', 'k8s_namespace_name'];

local cases = [
  {
    name: 'appends the grouping attribute',
    by: by,
    config: { custom: { groupingAttributes: ['env'] } },
    expected: by + ['env'],
  },
  {
    name: 'dedupes an attribute the query already groups by',
    by: by,
    config: { custom: { groupingAttributes: ['k8s_namespace_name'] } },
    expected: by,
  },
  {
    name: 'stays unaggregated when by is null',
    by: null,
    config: { custom: { groupingAttributes: ['env'] } },
    expected: null,
  },
];

{
  testMaybeWithGrouping:
    local failures = [
      '%s\n  expected: %s\n  got:      %s' % [case.name, std.toString(case.expected), std.toString(result)]
      for case in cases
      for result in [grouping.maybeWithGrouping(case.by, case.config)]
      if result != case.expected
    ];
    assert failures == [] :
           'maybeWithGrouping decides the label set of every aggregation in every dashboard query and quota alert. Dropping an attribute from one level makes a division match nothing; duplicating one is invalid PromQL.\n\n%s' % std.join('\n\n', failures);
    'PASS: maybeWithGrouping appends, dedupes and passes through null',

  testMaybeWithGroupingHandlesAbsentConfig:
    local failures = [
      'config %s produced %s' % [std.toString(config), std.toString(result)]
      for config in [{}, { custom: {} }, { custom: { groupingAttributes: [] } }]
      for result in [grouping.maybeWithGrouping(by, config)]
      if result != by
    ];
    assert failures == [] :
           'each of these config shapes exercises a different std.get fallback; a missing default crashes every query rather than degrading.\n%s' % std.join('\n', failures);
    'PASS: an unset custom.groupingAttributes leaves by untouched',
}
