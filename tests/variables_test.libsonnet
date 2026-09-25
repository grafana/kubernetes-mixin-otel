local commonVariables = import '../dashboards/resources/variables/common.libsonnet';

local config = {
  datasourceName: 'default',
  datasourceFilterRegex: '',
  customAttributes: [],
};

local configWithCustomAttributes = config {
  customAttributes: [{ label: 'env', operator: '=', value: 'prod' }],
};

local datasource = commonVariables.datasource(config);

{
  testNamespaceVariableUnfilteredByDefault:
    local result = commonVariables.namespace(datasource, config).query;
    local expected = 'label_values(k8s_namespace_phase, k8s_namespace_name)';
    assert result == expected :
           'namespace variable query changed unexpectedly with no customAttributes.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: namespace variable query unchanged when customAttributes is unset',

  testNamespaceVariableAppliesCustomAttributes:
    local result = commonVariables.namespace(datasource, configWithCustomAttributes).query;
    local expected = 'label_values(k8s_namespace_phase{env="prod"}, k8s_namespace_name)';
    assert result == expected :
           'customAttributes not applied to namespace variable.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to namespace variable',
}
