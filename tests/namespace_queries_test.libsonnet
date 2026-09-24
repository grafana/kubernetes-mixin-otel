local namespace = import '../dashboards/resources/queries/namespace.libsonnet';

local config = {
  extraAttributes: [],
  extraGroupingAttributes: [],
};

local configWithExtraAttributes = config {
  extraAttributes: [{ label: 'env', operator: '=', value: 'prod' }],
};

local configWithExtraGroupingAttributes = config {
  extraGroupingAttributes: ['asserts_env'],
};

local expectedCpuUsageByPod =
  'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"}[$__rate_interval])))';

local expectedMemoryUsageByPod =
  'sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"}))';

local expectedCpuUtilisationFromRequests =
  'sum(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"}[$__rate_interval])) / sum by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_container_cpu_request{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"})))';

local expectedMemoryUtilisationFromRequests =
  'sum(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"}) / sum by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"})))';

{
  testCpuUsageByPod:
    local result = namespace.cpuUsageByPod(config);
    assert result == expectedCpuUsageByPod :
           'cpuUsageByPod failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedCpuUsageByPod, result];
    'PASS: cpuUsageByPod',

  testMemoryUsageByPod:
    local result = namespace.memoryUsageByPod(config);
    assert result == expectedMemoryUsageByPod :
           'memoryUsageByPod failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedMemoryUsageByPod, result];
    'PASS: memoryUsageByPod',

  testCpuUtilisationFromRequests:
    local result = namespace.cpuUtilisationFromRequests(config);
    assert result == expectedCpuUtilisationFromRequests :
           'cpuUtilisationFromRequests failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedCpuUtilisationFromRequests, result];
    'PASS: cpuUtilisationFromRequests',

  testMemoryUtilisationFromRequests:
    local result = namespace.memoryUtilisationFromRequests(config);
    assert result == expectedMemoryUtilisationFromRequests :
           'memoryUtilisationFromRequests failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedMemoryUtilisationFromRequests, result];
    'PASS: memoryUtilisationFromRequests',

  testExtraAttributes:
    local queries = [
      namespace.cpuUsageByPod(configWithExtraAttributes),  // normal (rateSumPodLevel)
      namespace.cpuRequestsByPod(configWithExtraAttributes),  // active-phase (metricSumActiveOnly)
    ];
    assert std.all([std.length(std.findSubstr('env="prod"', q)) > 0 for q in queries]) :
           'extraAttributes not applied to one or more query paths.\nGot:\n%s' % std.toString(queries);
    'PASS: extraAttributes applied to normal and active-phase query paths',

  testExtraGroupingAttributesActivePhaseJoinLockstep:
    local result = namespace.cpuRequestsByPod(configWithExtraGroupingAttributes);
    assert std.length(std.findSubstr(
      'on (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, asserts_env) group_left() clamp_max(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, asserts_env)',
      result
    )) > 0 :
           'on(...) and its paired max by(...) drifted out of lockstep.\nGot:\n%s' % result;
    'PASS: extraGroupingAttributes keeps on(...) and max by(...) in lockstep in the active-phase join',

  testExtraGroupingAttributesScalarStaysScalar:
    local result = namespace.cpuUtilisationFromRequests(configWithExtraGroupingAttributes);
    assert std.startsWith(result, 'sum(') :
           'a scalar (by=null) query unexpectedly grouped by extraGroupingAttributes.\nGot:\n%s' % result;
    'PASS: extraGroupingAttributes leaves a scalar (by=null) query scalar',

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
