local pod = import '../dashboards/resources/queries/pod.libsonnet';

local config = {
  extraAttributes: [],
};

local configWithExtraAttributes = config {
  extraAttributes: [{ label: 'env', operator: '=', value: 'prod' }],
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
    local result = pod.cpuUsageByContainer(configWithExtraAttributes);
    assert std.length(std.findSubstr('env="prod"', result)) > 0 :
           'extraAttributes not applied to query.\nGot:\n%s' % result;
    'PASS: extraAttributes applied to query',

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
