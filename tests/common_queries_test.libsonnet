local common = import '../dashboards/resources/queries/common.libsonnet';

{
  testSelectorExtraAttributes:
    local result = common.selector(
      'k8s_pod_cpu_time_seconds_total',
      { k8s_cluster_name: '${cluster:pipe}' },
      extraAttributes=[{ label: 'env', operator: '=', value: 'prod' }]
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}", env="prod"}';
    assert result == expected :
           'selector with extraAttributes failed.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector applies extraAttributes',
}
