local common = import '../dashboards/resources/queries/common.libsonnet';

{
  testSelectorMergesCustomAttributes:
    local result = common.selector(
      'k8s_pod_cpu_time_seconds_total',
      { k8s_cluster_name: '${cluster:pipe}' },
      config={ customAttributes: [{ label: 'env', operator: '=', value: 'prod' }] }
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{env="prod", k8s_cluster_name=~"${cluster:pipe}"}';
    assert result == expected :
           'selector with config.customAttributes failed.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector merges config.customAttributes into the metric selector',

  testSelectorCustomAttributesWinOnLabelCollision:
    local result = common.selector(
      'k8s_pod_network_io_bytes_total',
      {},
      attributes=[{ label: 'direction', operator: '=', value: 'transmit' }],
      config={ customAttributes: [{ label: 'direction', operator: '=', value: 'receive' }] }
    );
    local expected = 'k8s_pod_network_io_bytes_total{direction="receive"}';
    assert result == expected :
           'customAttributes did not win on label collision.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes wins over attributes on label collision',

  testSelectorHandlesConfigMissingCustomAttributes:
    local result = common.selector(
      'k8s_pod_cpu_time_seconds_total',
      { k8s_cluster_name: '${cluster:pipe}' },
      config={}
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}"}';
    assert result == expected :
           'selector crashed or misbehaved when config has no customAttributes key.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector defaults to no custom attributes when config lacks the key',
}
