local namespace = import '../../dashboards/resources/queries/namespace.libsonnet';

local config = (import '../../config.libsonnet')._config;

local configWithCustomAttributes = config {
  custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
};

{
  testCustomAttributesOnActivePhaseJoin:
    local result = namespace.cpuRequestsByPod(configWithCustomAttributes);
    assert std.length(std.findSubstr('env="prod"', result)) == 3 :
           'customAttributes not applied to both the main selector and the active-phase join selector.\nGot:\n%s' % result;
    'PASS: customAttributes applied to both the main selector and the active-phase join selector',

  testCustomAttributesOnRatioActivePhaseJoin:
    local result = namespace.cpuUsageVsRequests(configWithCustomAttributes);
    assert std.length(std.findSubstr('env="prod"', result)) == 4 :
           'customAttributes not applied to numerator, denominator, and both active-phase join comparisons.\nGot:\n%s' % result;
    'PASS: customAttributes applied to numerator, denominator, and the active-phase join',

  testMemoryQueriesUseTheirIntendedMetric:
    local expected = {
      memoryUsageByPod: 'k8s_pod_memory_working_set_bytes',
      memoryUsageRSS: 'k8s_pod_memory_rss_bytes',
      memoryUtilisationFromRequests: 'k8s_pod_memory_working_set_bytes',
    };
    local failures = [
      '%s does not read %s' % [name, expected[name]]
      for name in std.objectFields(expected)
      if !std.member(namespace[name](config), expected[name])
    ];
    assert failures == [] :
           'working set is what OOM-kill decisions are based on and is always lower than usage, which includes reclaimable cache. A panel reading the wrong one is a silent correctness bug.\n%s' % std.join('\n', failures);
    'PASS: memory panels read working_set or rss as intended',

  testAllRatioQueries:
    local queries = [
      namespace.cpuUtilisationFromRequests(config),
      namespace.cpuUtilisationFromLimits(config),
      namespace.memoryUtilisationFromRequests(config),
      namespace.memoryUtilisationFromLimits(config),
    ];
    assert std.all([q != null && q != '' && q != '0' for q in queries]) :
           'Some ratio queries are not implemented';
    'PASS: all 4 ratio queries implemented',
}
