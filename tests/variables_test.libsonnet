local commonVariables = import '../dashboards/resources/variables/common.libsonnet';
local baseConfig = (import '../config.libsonnet')._config;

local config = baseConfig { extraAttributes: [] };

local configWithExtraAttributes = config {
  extraAttributes: [
    { label: 'asserts_env', operator: '=', value: 'prod' },
    { label: 'asserts_site', operator: '=~', value: 'us.*' },
  ],
};

local datasource = commonVariables.datasource(config);

{
  testClusterVariableDefault:
    local result = commonVariables.cluster(config, datasource).query;
    assert result == 'label_values(k8s_node_condition_ready{}, k8s_cluster_name)' :
           'cluster variable query changed.\nGot:\n%s' % result;
    'PASS: cluster variable query unchanged with no extraAttributes',

  testClusterVariableWithExtraAttributes:
    local result = commonVariables.cluster(configWithExtraAttributes, datasource).query;
    assert result == 'label_values(k8s_node_condition_ready{asserts_env="prod", asserts_site=~"us.*"}, k8s_cluster_name)' :
           'cluster variable query did not apply extraAttributes.\nGot:\n%s' % result;
    'PASS: cluster variable query applies extraAttributes',

  testNamespaceVariableDefault:
    local result = commonVariables.namespace(config, datasource).query;
    assert result == 'label_values(k8s_namespace_phase{}, k8s_namespace_name)' :
           'namespace variable query changed.\nGot:\n%s' % result;
    'PASS: namespace variable query unchanged with no extraAttributes',

  testNamespaceVariableWithExtraAttributes:
    local result = commonVariables.namespace(configWithExtraAttributes, datasource).query;
    assert result == 'label_values(k8s_namespace_phase{asserts_env="prod", asserts_site=~"us.*"}, k8s_namespace_name)' :
           'namespace variable query did not apply extraAttributes.\nGot:\n%s' % result;
    'PASS: namespace variable query applies extraAttributes',

  testPodVariableDefault:
    local result = commonVariables.pod(config, datasource).query;
    assert result == 'label_values(k8s_pod_phase{}, k8s_pod_name)' :
           'pod variable query changed.\nGot:\n%s' % result;
    'PASS: pod variable query unchanged with no extraAttributes',

  testPodVariableWithExtraAttributes:
    local result = commonVariables.pod(configWithExtraAttributes, datasource).query;
    assert result == 'label_values(k8s_pod_phase{asserts_env="prod", asserts_site=~"us.*"}, k8s_pod_name)' :
           'pod variable query did not apply extraAttributes.\nGot:\n%s' % result;
    'PASS: pod variable query applies extraAttributes',
}
