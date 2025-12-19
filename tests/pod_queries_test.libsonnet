local pod = import '../dashboards/resources/queries/pod.libsonnet';

local config = {
  _config: {},
};

local expectedWithRate =
  'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}[$__rate_interval])) / max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_container_cpu_request{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}))';

local expectedWithoutRate =
  'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_pod_memory_usage_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}) / max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}))';

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
