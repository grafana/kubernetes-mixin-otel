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

  testRateAvgAppliesCustomAttributes:
    local result = common.rateAvg(
      'k8s_pod_cpu_time_seconds_total',
      {},
      config={ customAttributes: [{ label: 'env', operator: '=', value: 'prod' }] }
    );
    local expected = 'avg(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (rate(k8s_pod_cpu_time_seconds_total{env="prod"}[$__rate_interval])))';
    assert result == expected :
           'customAttributes not applied to rateAvg.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to rateAvg',

  testRatioSumAppliesCustomAttributesToBothSides:
    local result = common.ratioSum(
      'metricA',
      'metricB',
      {},
      config={ customAttributes: [{ label: 'env', operator: '=', value: 'prod' }] }
    );
    local expected = 'sum(max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (metricA{env="prod"}) / max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_container_name) (metricB{env="prod"}))';
    assert result == expected :
           'customAttributes not applied to both sides of ratioSum.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: customAttributes applied to both sides of ratioSum',

  testRatioSumActiveOnlyAppliesCustomAttributesToAllArms:
    local result = common.ratioSumActiveOnly(
      'metricA',
      'metricB',
      {},
      {},
      config={ customAttributes: [{ label: 'env', operator: '=', value: 'prod' }] }
    );
    assert std.length(std.findSubstr('env="prod"', result)) == 4 :
           'customAttributes not applied to numerator, denominator, and both active-phase join comparisons.\nGot:\n%s' % result;
    'PASS: customAttributes applied to numerator, denominator, and the active-phase join',
}
