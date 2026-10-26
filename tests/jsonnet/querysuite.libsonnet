local shape = import './exprshape.libsonnet';

local unimplemented = '0';

local renderAll(queries, config) = {
  [name]: queries[name](config)
  for name in std.objectFieldsAll(queries)
  if std.isFunction(queries[name])
};

local implemented(rendered) = [
  name
  for name in std.objectFields(rendered)
  if rendered[name] != unimplemented
];

{
  renderAll:: renderAll,
  implemented:: implemented,

  // Every selector in every implemented query carries the matcher.
  customAttributesReachEverySelector(queries, config, matcher):: (
    local rendered = renderAll(queries, config);
    local failures = [
      '%s left %s unfiltered' % [name, selector.metric]
      for name in implemented(rendered)
      for selector in shape.selectors(rendered[name])
      if !std.member(selector.matchers, matcher)
    ];
    assert failures == [] :
           'custom.attributes must reach every selector of every query; a filtered arm compared against an unfiltered one matches nothing.\n%s' % std.join('\n', failures);
    'PASS: custom.attributes reach every selector of all %d implemented queries' % std.length(implemented(rendered))
  ),

  // Guards the OTel metric choice per panel, e.g. working_set over usage.
  queriesUseExpectedMetrics(queries, config, expected):: (
    local rendered = renderAll(queries, config);
    local failures = [
      '%s reads %s, expected %s' % [name, std.toString(shape.metrics(rendered[name])), std.toString(expected[name])]
      for name in std.objectFields(expected)
      if shape.metrics(rendered[name]) != std.set(expected[name])
    ];
    assert failures == [] :
           'a panel reading the wrong metric is a silent correctness bug: working_set is what OOM-kill decisions use, usage includes reclaimable cache, and allocatable is post-overhead.\n%s' % std.join('\n', failures);
    'PASS: %d queries read their intended metrics' % std.length(std.objectFields(expected))
  ),

  // Dedup tuple has to match the cardinality of the metric being deduped.
  dedupTuplesMatchCardinality(queries, config, tuples):: (
    local rendered = renderAll(queries, config);
    local failures = [
      '%s dedups by %s, expected %s' % [name, std.toString(shape.aggregations(rendered[name])), std.toString(tuples[name])]
      for name in std.objectFields(tuples)
      if !std.member(shape.aggregations(rendered[name]), tuples[name])
    ];
    assert failures == [] :
           'deduping a pod-level metric with the container tuple multiplies it by the container count.\n%s' % std.join('\n', failures);
    'PASS: %d queries dedup at the cardinality of their metric' % std.length(std.objectFields(tuples))
  ),

  // No implemented query may aggregate without deduping first.
  everyQueryDedupsBeforeAggregating(queries, config):: (
    local rendered = renderAll(queries, config);
    local failures = [
      '%s has no aggregation at all' % name
      for name in implemented(rendered)
      if shape.aggregations(rendered[name]) == []
    ];
    assert failures == [] :
           'two collectors can report the same pod or container simultaneously, so every query must dedup with max by (...) before aggregating or the result doubles.\n%s' % std.join('\n', failures);
    'PASS: every implemented query aggregates over an explicit label set'
  ),
}
