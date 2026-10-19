local common = import '../dashboards/resources/queries/common.libsonnet';

{
  testRateAvgAppliesCustomAttributes:
    local result = common.rateAvg(
      'k8s_pod_cpu_time_seconds_total',
      {},
      config={ custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } }
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
      config={ custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } }
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
      config={ custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } }
    );
    assert std.length(std.findSubstr('env="prod"', result)) == 4 :
           'customAttributes not applied to numerator, denominator, and both active-phase join comparisons.\nGot:\n%s' % result;
    'PASS: customAttributes applied to numerator, denominator, and the active-phase join',
}
