local namespace = import '../dashboards/resources/queries/namespace.libsonnet';

local config = {
  _config: {},
};

local expectedCpuUsageByPod =
  "sum by (k8s_pod_name) (\n" +
  "  max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (\n" +
  '    rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}[$__rate_interval])\n' +
  "  )\n" +
  ")";

local expectedMemoryUsageByPod =
  "sum by (k8s_pod_name) (\n" +
  "  max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (\n" +
  '    k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}\n' +
  "  )\n" +
  ")";

local expectedCpuUtilisationFromRequests =
  "sum(\n" +
  "  max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (\n" +
  '    rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}[$__rate_interval])\n' +
  "  )\n" +
  "/\n" +
  "max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (\n" +
  '    k8s_container_cpu_request{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}\n' +
  "  )\n" +
  "\n" +
  ")";

local expectedMemoryUtilisationFromRequests =
  "sum(\n" +
  "  max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (\n" +
  '    k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}\n' +
  "  )\n" +
  "/\n" +
  "max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (\n" +
  '    k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster}", k8s_namespace_name=~"${namespace}"}\n' +
  "  )\n" +
  "\n" +
  ")";

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
