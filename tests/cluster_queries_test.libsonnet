local cluster = import '../dashboards/resources/queries/cluster.libsonnet';

local config = {
  _config: {},
};

local expectedCpuUsageByNamespace =
  'sum by (k8s_cluster_name, k8s_namespace_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (rate(k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}"}[$__rate_interval])))';

local expectedMemoryUsageByNamespace =
  'sum by (k8s_cluster_name, k8s_namespace_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (k8s_pod_memory_working_set_bytes{k8s_cluster_name=~"${cluster:pipe}"}))';

{
  testCpuUsageByNamespace:
    local result = cluster.cpuUsageByNamespace(config);
    assert result == expectedCpuUsageByNamespace :
           'cpuUsageByNamespace failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedCpuUsageByNamespace, result];
    'PASS: cpuUsageByNamespace',

  testMemoryUsageByNamespace:
    local result = cluster.memoryUsageByNamespace(config);
    assert result == expectedMemoryUsageByNamespace :
           'memoryUsageByNamespace failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedMemoryUsageByNamespace, result];
    'PASS: memoryUsageByNamespace',
}
