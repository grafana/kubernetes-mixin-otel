local cluster = import '../dashboards/resources/queries/cluster.libsonnet';

local config = (import '../config.libsonnet')._config;

local configWithCustomAttributes = config {
  customAttributes: [{ label: 'env', operator: '=', value: 'prod' }],
};

local expectedMemoryUsageByNamespace =
  'sum by (k8s_cluster_name, k8s_namespace_name) (k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}"})';

{
  testCpuUsageByNamespaceUsesPipeForMultiValueCluster:
    local result = cluster.cpuUsageByNamespace(config);
    assert std.length(std.findSubstr('${cluster:pipe}', result)) > 0 :
           'cpuUsageByNamespace must use ${cluster:pipe} so a multi-select cluster variable interpolates as a valid regex alternation.\nGot:\n%s' % result;
    'PASS: cpuUsageByNamespace uses ${cluster:pipe}',

  testMemoryUsageByNamespace:
    local result = cluster.memoryUsageByNamespace(config);
    assert result == expectedMemoryUsageByNamespace :
           'memoryUsageByNamespace failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedMemoryUsageByNamespace, result];
    'PASS: memoryUsageByNamespace',

  testCustomAttributesOnMemoryUsageByNamespace:
    local result = cluster.memoryUsageByNamespace(configWithCustomAttributes);
    local expected = 'sum by (k8s_cluster_name, k8s_namespace_name) (k8s_container_memory_request_bytes{env="prod", k8s_cluster_name=~"${cluster:pipe}"})';
    assert result == expected :
           'customAttributes not applied to memoryUsageByNamespace.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to memoryUsageByNamespace',
}
