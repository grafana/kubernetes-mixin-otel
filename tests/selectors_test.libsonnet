local selectors = import '../lib/selectors.libsonnet';

{
  testSelectorMergesCustomAttributes:
    local result = selectors.selector(
      'k8s_pod_cpu_time_seconds_total',
      { k8s_cluster_name: '${cluster:pipe}' },
      config={ custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } }
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{env="prod", k8s_cluster_name=~"${cluster:pipe}"}';
    assert result == expected :
           'selector with config.custom.attributes failed.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector merges config.custom.attributes into the metric selector',

  testSelectorAllowsRepeatedNegativeMatchersOnSameLabel:
    local result = selectors.selector(
      'k8s_pod_cpu_time_seconds_total',
      {},
      config={ custom: { attributes: [
        { label: 'env', operator: '!=', value: 'dev' },
        { label: 'env', operator: '!=', value: 'staging' },
      ] } }
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{env!="dev", env!="staging"}';
    assert result == expected :
           'selector rejected non-empty repeated negative matchers on the same label.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector allows repeated != matchers on the same label',

  testSelectorAllowsRepeatedRegexMatchersOnSameLabel:
    local result = selectors.selector(
      'k8s_pod_cpu_time_seconds_total',
      {},
      config={ custom: { attributes: [
        { label: 'env', operator: '=~', value: 'prod.*' },
        { label: 'env', operator: '=~', value: '.*eu' },
      ] } }
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{env=~"prod.*", env=~".*eu"}';
    assert result == expected :
           'selector rejected repeated regex matchers on the same label.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector allows repeated =~ matchers on the same label',

  testSelectorHandlesConfigMissingCustomAttributes:
    local result = selectors.selector(
      'k8s_pod_cpu_time_seconds_total',
      { k8s_cluster_name: '${cluster:pipe}' },
      config={}
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}"}';
    assert result == expected :
           'selector crashed or misbehaved when config has no custom key.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector defaults to no custom attributes when config lacks the custom key',

  testSelectorHandlesCustomMissingAttributes:
    local result = selectors.selector(
      'k8s_pod_cpu_time_seconds_total',
      { k8s_cluster_name: '${cluster:pipe}' },
      config={ custom: {} }
    );
    local expected = 'k8s_pod_cpu_time_seconds_total{k8s_cluster_name=~"${cluster:pipe}"}';
    assert result == expected :
           'selector crashed or misbehaved when config.custom has no attributes key.\nExpected:\n%s\n\nGot:\n%s' % [expected, result];
    'PASS: selector defaults to no custom attributes when config.custom lacks the attributes key',

  testWithCustomAttributesOmitsEmptySelector:
    local result = selectors.withCustomAttributes('k8s_node_condition_ready', { custom: { attributes: [] } });
    assert result == 'k8s_node_condition_ready' :
           'withCustomAttributes should return the bare metric when no custom attributes are set.\nGot:\n%s' % result;
    'PASS: withCustomAttributes returns the bare metric when unset',

  testWithCustomAttributesAppliesMatchers:
    local result = selectors.withCustomAttributes('k8s_node_condition_ready', { custom: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] } });
    assert result == 'k8s_node_condition_ready{env="prod"}' :
           'withCustomAttributes did not apply config.custom.attributes.\nGot:\n%s' % result;
    'PASS: withCustomAttributes applies config.custom.attributes',
}
