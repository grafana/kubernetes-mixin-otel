local pod = import '../dashboards/resources/queries/pod.libsonnet';

local config = {
  extraAttributes: [],
  extraGroupingAttributes: [],
};

local configWithExtraAttributes = config {
  extraAttributes: [{ label: 'env', operator: '=', value: 'prod' }],
};

local configWithExtraGroupingAttributes = config {
  extraGroupingAttributes: ['asserts_env', 'asserts_site'],
};

local expectedWithRate =
  'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}[$__rate_interval])) / sum by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_container_cpu_request{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"})))';

local expectedWithoutRate =
  'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}) / sum by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"})))';

{
  testRatioWithRate:
    local result = pod.cpuUsageVsRequests(config);
    assert result == expectedWithRate :
           'ratio with useRate=true failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedWithRate, result];
    'PASS: ratio with useRate=true',

  testRatioWithoutRate:
    local result = pod.memoryUsageVsRequests(config);
    assert result == expectedWithoutRate :
           'ratio with useRate=false failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedWithoutRate, result];
    'PASS: ratio with useRate=false',

  testExtraAttributes:
    local queries = [
      pod.cpuUsageByContainer(configWithExtraAttributes),  // normal (rateSum)
      pod.networkReceiveBandwidth(configWithExtraAttributes),  // directional (selectors + extraAttributes)
      pod.cpuUsageVsRequests(configWithExtraAttributes),  // ratio (ratioSumPodLevel)
    ];
    assert std.all([std.length(std.findSubstr('env="prod"', q)) > 0 for q in queries]) :
           'extraAttributes not applied to one or more query paths.\nGot:\n%s' % std.toString(queries);
    'PASS: extraAttributes applied to normal, directional, and ratio query paths',

  testExtraGroupingAttributes:
    local queries = [
      pod.cpuUsageByContainer(configWithExtraGroupingAttributes),  // normal (rateSum)
      pod.networkReceiveBandwidth(configWithExtraGroupingAttributes),  // directional (selectors + extraGroupingAttributes)
      pod.cpuUsageVsRequests(configWithExtraGroupingAttributes),  // ratio (ratioSumPodLevel)
    ];
    assert std.all([std.length(std.findSubstr(', asserts_env, asserts_site)', q)) >= 2 for q in queries]) :
           'extraGroupingAttributes not widening both by(...) levels on one or more query paths.\nGot:\n%s' % std.toString(queries);
    'PASS: extraGroupingAttributes widens by(...) on normal, directional, and ratio query paths',

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
