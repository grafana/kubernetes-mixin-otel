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

  testNetworkBandwidthGroupsByPod:
    local queries = [namespace[name](config) for name in ['networkReceiveBandwidth', 'networkTransmitBandwidth', 'networkReceiveBandwidthTimeSeries', 'networkTransmitBandwidthTimeSeries']];
    assert std.all([std.startsWith(q, 'sum by (k8s_pod_name) (') for q in queries]) :
           'the Current Network Usage table joins on k8s_pod_name; grouping by anything else leaves it with no data.\nGot:\n%s' % std.toString(queries);
    'PASS: network bandwidth groups by pod',

  testNetworkBandwidthSumsInterfaces:
    local queries = [namespace[name](config) for name in ['networkReceiveBandwidth', 'networkTransmitBandwidth', 'networkReceiveBandwidthTimeSeries', 'networkTransmitBandwidthTimeSeries']];
    assert std.all([std.member(q, 'k8s_pod_name, interface)') for q in queries]) :
           'dedup must keep `interface`, or a multi-interface pod shows only its busiest interface instead of the total.\nGot:\n%s' % std.toString(queries);
    'PASS: network bandwidth sums across interfaces',

  testNetworkPacketsDroppedUnmapped:
    local failures = [name for name in ['networkReceivePacketsDropped', 'networkTransmitPacketsDropped'] if namespace[name](config) != '0'];
    assert failures == [] :
           'kubeletstats has no dropped-packet metric; k8s.pod.network.errors is not a substitute for drops.\nNot 0: %s' % std.join(', ', failures);
    'PASS: packets dropped panels return 0',
}
