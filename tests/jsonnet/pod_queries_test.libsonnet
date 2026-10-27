local pod = import '../../dashboards/resources/queries/pod.libsonnet';

local config = (import '../../config.libsonnet')._config;

local configWithCustomAttributes = config {
  custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
};

{
  testCustomAttributesMergeWithDirectionalAttributes:
    local result = pod.networkReceiveBandwidth(configWithCustomAttributes);
    local failures = [
      matcher
      for matcher in ['direction="receive"', 'env="prod"']
      if !std.member(result, matcher)
    ];
    assert failures == [] :
           'a per-panel attribute and custom.attributes must both survive the merge; values overrides defaultSelectors for the same label rather than ANDing them, so one silently wins.\nMissing: %s\nGot:\n%s' % [std.join(', ', failures), result];
    'PASS: customAttributes merge with directional attributes',

  testCustomAttributesOnSingleSelectorBuilders:
    local queries = [
      pod.cpuUsageByContainer(configWithCustomAttributes),  // rateSum
      pod.cpuRequests(configWithCustomAttributes),  // metricSum
    ];
    assert std.all([std.length(std.findSubstr('env="prod"', q)) == 1 for q in queries]) :
           'customAttributes not applied to one or more single-selector builders.\nGot:\n%s' % std.toString(queries);
    'PASS: customAttributes applied to rateSum and metricSum (single-selector builders)',

  testMemoryQueriesUseTheirIntendedMetric:
    local expected = {
      memoryUsageWSS: 'k8s_pod_memory_working_set_bytes',
      memoryUsageRSS: 'k8s_pod_memory_rss_bytes',
      memoryUsageVsRequests: 'k8s_pod_memory_working_set_bytes',
    };
    local failures = [
      '%s does not read %s' % [name, expected[name]]
      for name in std.objectFields(expected)
      if !std.member(pod[name](config), expected[name])
    ];
    assert failures == [] :
           'working set is what OOM-kill decisions are based on and is always lower than usage, which includes reclaimable cache. A panel reading the wrong one is a silent correctness bug.\n%s' % std.join('\n', failures);
    'PASS: memory panels read working_set or rss as intended',

  testMemoryUsageCacheSubtractsRssFromUsage:
    local result = pod.memoryUsageCache(config);
    local failures = [
      metric
      for metric in ['k8s_pod_memory_usage_bytes', 'k8s_pod_memory_rss_bytes']
      if !std.member(result, metric)
    ];
    assert failures == [] && std.member(result, ' - ') :
           'cache is usage minus rss; usage is the only metric that includes reclaimable page cache, so this panel is the one place usage is correct.\nMissing: %s\nGot:\n%s' % [std.join(', ', failures), result];
    'PASS: memoryUsageCache subtracts rss from usage',

  testAllRatioQueries:
    local queries = [
      pod.cpuUsageVsRequests(config),
      pod.cpuUsageVsLimits(config),
      pod.memoryUsageVsRequests(config),
      pod.memoryUsageVsLimits(config),
    ];
    assert std.all([q != null && q != '' && q != '0' for q in queries]) :
           'Some ratio queries are not implemented';
    'PASS: all 4 ratio queries implemented',
}
