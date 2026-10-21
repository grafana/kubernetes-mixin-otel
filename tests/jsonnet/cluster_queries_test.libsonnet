local cluster = import '../../dashboards/resources/queries/cluster.libsonnet';

local config = (import '../../config.libsonnet')._config;

local configWithCustomAttributes = config {
  custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
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

  testCustomAttributesOnCpuUsageByNamespace:
    local result = cluster.cpuUsageByNamespace(configWithCustomAttributes);
    local expected = 'sum by (k8s_cluster_name, k8s_namespace_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (rate(k8s_pod_cpu_time_seconds_total{env="prod", k8s_cluster_name=~"${cluster:pipe}"}[$__rate_interval])))';
    assert result == expected :
           'customAttributes not applied to cpuUsageByNamespace.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to cpuUsageByNamespace',

  testMemoryUsageByNamespace:
    local result = cluster.memoryUsageByNamespace(config);
    assert result == expectedMemoryUsageByNamespace :
           'memoryUsageByNamespace failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedMemoryUsageByNamespace, result];
    'PASS: memoryUsageByNamespace',

  testCustomAttributesOnMemoryUsageByNamespace:
    local result = cluster.memoryUsageByNamespace(configWithCustomAttributes);
    local expected = 'sum by (k8s_cluster_name, k8s_namespace_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (k8s_pod_memory_working_set_bytes{env="prod", k8s_cluster_name=~"${cluster:pipe}"}))';
    assert result == expected :
           'customAttributes not applied to memoryUsageByNamespace.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to memoryUsageByNamespace',
}
