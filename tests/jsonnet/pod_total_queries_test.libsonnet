local podTotal = import '../../dashboards/network-usage/queries/pod-total.libsonnet';

local config = (import '../../config.libsonnet')._config;

local configWithCustomAttributes = config {
  custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
};

local configInBytes = config {
  units+: { network: 'binBps', networkMultiplier: 1 },
};

{
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

  testGaugesGroupByPod:
    local queries = [
      podTotal.gaugeReceiveBandwidth(config),
      podTotal.gaugeTransmitBandwidth(config),
    ];
    assert std.all([std.startsWith(q, '(sum by (k8s_pod_name) (') for q in queries]) :
           'the pod variable is multi-select, so gauges must group by pod or "All" sums every pod into one value.\nGot:\n%s' % std.toString(queries);
    'PASS: gauge queries group by pod',

  testGaugesLabelledPerPod:
    local panels = (import '../../mixin.libsonnet').grafanaDashboards['pod-total.json'].panels;
    local gauges = [p for p in panels if p.type == 'gauge'];
    assert std.length(gauges) == 2 && std.all([g.fieldConfig.defaults.displayName == '${__field.labels.k8s_pod_name}' for g in gauges]) :
           "upstream's `$pod` display name would put every selected pod's name on each gauge.\nGot:\n%s" % std.toString([g.fieldConfig.defaults.displayName for g in gauges]);
    'PASS: each gauge is labelled with its own pod',

  testDirectionMatchesPanel:
    local expected = {
      gaugeReceiveBandwidth: 'receive',
      gaugeTransmitBandwidth: 'transmit',
      receiveBandwidth: 'receive',
      transmitBandwidth: 'transmit',
    };
    local failures = [
      name
      for name in std.objectFields(expected)
      if !std.member(podTotal[name](config), 'direction="%s"' % expected[name])
    ];
    assert failures == [] :
           'receive/transmit panels share one OTel metric split by direction; a swapped direction is a silent correctness bug.\nWrong direction: %s' % std.join(', ', failures);
    'PASS: each query filters on the direction of its panel',

  testInterfacesSummedNotDeduplicated:
    local queries = [
      podTotal[name](config)
      for name in std.objectFieldsAll(podTotal)
      if podTotal[name](config) != '0'
    ];
    assert std.all([std.member(q, 'k8s_pod_name, interface)') for q in queries]) :
           'dedup must keep `interface`, or a multi-interface pod shows only its busiest interface instead of the total.\nGot:\n%s' % std.toString(queries);
    'PASS: network queries sum across interfaces',

  testUnmappedPanelsReturnZero:
    local names = ['receivePackets', 'transmitPackets', 'receivePacketsDropped', 'transmitPacketsDropped'];
    local failures = [name for name in names if podTotal[name](config) != '0'];
    assert failures == [] :
           'kubeletstats has no packet or dropped-packet metric; k8s.pod.network.errors is not a substitute for drops.\nNot 0: %s' % std.join(', ', failures);
    'PASS: unmapped packet panels return 0',

  testCustomAttributesApplied:
    local queries = [
      podTotal.gaugeReceiveBandwidth(configWithCustomAttributes),
      podTotal.receiveBandwidth(configWithCustomAttributes),
    ];
    assert std.all([std.member(q, 'env="prod"') && std.member(q, 'direction="receive"') for q in queries]) :
           'customAttributes must merge with the direction attribute.\nGot:\n%s' % std.toString(queries);
    'PASS: customAttributes applied alongside direction',
}
