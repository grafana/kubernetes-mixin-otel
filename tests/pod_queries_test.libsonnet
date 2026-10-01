local pod = import '../dashboards/resources/queries/pod.libsonnet';

local config = (import '../config.libsonnet')._config;

local configWithCustomAttributes = config {
  custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
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

  testCustomAttributesOnRatio:
    local result = pod.cpuUsageVsRequests(configWithCustomAttributes);
    local expected = 'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (rate(k8s_pod_cpu_time_seconds_total{env="prod", k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}[$__rate_interval])) / sum by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_container_cpu_request{env="prod", k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"})))';
    assert result == expected :
           'customAttributes not applied to both sides of the ratio.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to both sides of ratioSumPodLevel',

  testCustomAttributesOnDirectional:
    local result = pod.networkReceiveBandwidth(configWithCustomAttributes);
    local expected = 'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (rate(k8s_pod_network_io_bytes_total{direction="receive", env="prod", k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}[$__rate_interval])))';
    assert result == expected :
           'customAttributes not merged with directional attributes.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes merges with directional attributes',

  testCustomAttributesOnSingleSelectorBuilders:
    local queries = [
      pod.cpuUsageByContainer(configWithCustomAttributes),  // rateSum
      pod.cpuRequests(configWithCustomAttributes),  // metricSum
    ];
    assert std.all([std.length(std.findSubstr('env="prod"', q)) == 1 for q in queries]) :
           'customAttributes not applied to one or more single-selector builders.\nGot:\n%s' % std.toString(queries);
    'PASS: customAttributes applied to rateSum and metricSum (single-selector builders)',

  testCustomAttributesOnDifference:
    local result = pod.memoryUsageCache(configWithCustomAttributes);
    local expected = 'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_pod_memory_usage_bytes{env="prod", k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}) - max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_pod_memory_rss_bytes{env="prod", k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}))';
    assert result == expected :
           'customAttributes not applied to both sides of differenceSum.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to both sides of differenceSum',

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
