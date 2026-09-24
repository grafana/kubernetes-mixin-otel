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
}
