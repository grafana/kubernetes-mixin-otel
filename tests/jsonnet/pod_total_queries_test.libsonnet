local podTotal = import '../../dashboards/network-usage/queries/pod-total.libsonnet';

local config = (import '../../config.libsonnet')._config;

local configWithCustomAttributes = config {
  custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
};

local configInBytes = config {
  units+: { network: 'binBps', networkMultiplier: 1 },
};

local expectedReceiveBandwidth =
  '(sum by (k8s_pod_name) (max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name) (rate(k8s_pod_network_io_bytes_total{direction="receive", k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}", k8s_pod_name=~"${pod:pipe}"}[$__rate_interval]))) * 8)';

{
  testReceiveBandwidth:
    local result = podTotal.receiveBandwidth(config);
    assert result == expectedReceiveBandwidth :
           'receiveBandwidth failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedReceiveBandwidth, result];
    'PASS: receiveBandwidth',

  testBandwidthHonoursNetworkMultiplier:
    local queries = [
      podTotal.gaugeReceiveBandwidth(configInBytes),
      podTotal.gaugeTransmitBandwidth(configInBytes),
      podTotal.receiveBandwidth(configInBytes),
      podTotal.transmitBandwidth(configInBytes),
    ];
    assert std.all([std.endsWith(q, ' * 1)') for q in queries]) :
           'bandwidth queries must scale by units.networkMultiplier, or the panel unit (bits vs bytes) is off by 8x.\nGot:\n%s' % std.toString(queries);
    'PASS: bandwidth queries honour units.networkMultiplier',

  testGaugesAggregateWithoutBy:
    local queries = [
      podTotal.gaugeReceiveBandwidth(config),
      podTotal.gaugeTransmitBandwidth(config),
    ];
    assert std.all([std.startsWith(q, '(sum(') for q in queries]) :
           'gauge panels show a single value and must not group by pod.\nGot:\n%s' % std.toString(queries);
    'PASS: gauge queries aggregate without a by clause',

  testDirectionMatchesPanel:
    local expected = {
      gaugeReceiveBandwidth: 'receive',
      gaugeTransmitBandwidth: 'transmit',
      receiveBandwidth: 'receive',
      transmitBandwidth: 'transmit',
      receivePacketsDropped: 'receive',
      transmitPacketsDropped: 'transmit',
    };
    local failures = [
      name
      for name in std.objectFields(expected)
      if !std.member(podTotal[name](config), 'direction="%s"' % expected[name])
    ];
    assert failures == [] :
           'receive/transmit panels share one OTel metric split by direction; a swapped direction is a silent correctness bug.\nWrong direction: %s' % std.join(', ', failures);
    'PASS: each query filters on the direction of its panel',

  testCustomAttributesApplied:
    local queries = [
      podTotal.gaugeReceiveBandwidth(configWithCustomAttributes),
      podTotal.receiveBandwidth(configWithCustomAttributes),
      podTotal.receivePacketsDropped(configWithCustomAttributes),
    ];
    assert std.all([std.member(q, 'env="prod"') && std.member(q, 'direction="receive"') for q in queries]) :
           'customAttributes must merge with the direction attribute.\nGot:\n%s' % std.toString(queries);
    'PASS: customAttributes applied alongside direction',
}
