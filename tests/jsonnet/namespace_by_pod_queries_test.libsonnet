local namespaceByPod = import '../../dashboards/network-usage/queries/namespace-by-pod.libsonnet';

local config = (import '../../config.libsonnet')._config;

local configWithCustomAttributes = config {
  custom+: { attributes: [{ label: 'env', operator: '=', value: 'prod' }] },
};

local configInBytes = config {
  units+: { network: 'binBps', networkMultiplier: 1 },
};

local bandwidthQueries = ['gaugeReceiveBandwidth', 'gaugeTransmitBandwidth', 'receiveBandwidth', 'transmitBandwidth'];

{
  testBandwidthHonoursNetworkMultiplier:
    local queries = [namespaceByPod[name](configInBytes) for name in bandwidthQueries];
    assert std.all([std.endsWith(q, ' * 1)') for q in queries]) :
           'bandwidth queries must scale by units.networkMultiplier, or the panel unit (bits vs bytes) is off by 8x.\nGot:\n%s' % std.toString(queries);
    'PASS: bandwidth queries honour units.networkMultiplier',

  testGaugesGroupByNamespace:
    local queries = [namespaceByPod.gaugeReceiveBandwidth(config), namespaceByPod.gaugeTransmitBandwidth(config)];
    assert std.all([std.startsWith(q, '(sum by (k8s_namespace_name) (') for q in queries]) :
           'the namespace variable is multi-select, so gauges must group by namespace or "All" sums every namespace into one value.\nGot:\n%s' % std.toString(queries);
    'PASS: gauge queries group by namespace',

  testTableQueriesGroupByPod:
    local queries = [namespaceByPod.receiveBandwidth(config), namespaceByPod.transmitBandwidth(config)];
    assert std.all([std.startsWith(q, '(sum by (k8s_pod_name) (') for q in queries]) :
           'the Current Network Usage table joins on k8s_pod_name; grouping by anything else leaves it with no data.\nGot:\n%s' % std.toString(queries);
    'PASS: table and time series queries group by pod',

  testDashboardUsesOtelLabels:
    local panels = (import '../../mixin.libsonnet').grafanaDashboards['namespace-by-pod.json'].panels;
    local gauges = [p for p in panels if p.type == 'gauge'];
    local table = [p for p in panels if p.type == 'table'][0];
    local join = [t for t in table.transformations if t.id == 'joinByField'][0];
    local organize = [t for t in table.transformations if t.id == 'organize'][0];
    assert std.length(gauges) == 2 && std.all([g.fieldConfig.defaults.displayName == '${__field.labels.k8s_namespace_name}' for g in gauges]) :
           "upstream's `$namespace` display name would put every selected namespace's name on each gauge.";
    assert join.options.byField == 'k8s_pod_name' && organize.options.renameByName.k8s_pod_name == 'Pod' && !std.objectHas(organize.options.renameByName, 'pod') :
           'the table must join on and rename k8s_pod_name, or it has no rows and the drill-down link ${__data.fields.Pod} breaks.\nGot:\n%s' % std.toString(table.transformations);
    local url = [o for o in table.fieldConfig.overrides if o.matcher.options == 'Pod'][0].properties[0].value[0].url;
    assert std.member(url, '${namespace:queryparam}') && std.member(url, '${cluster:queryparam}') && !std.member(url, 'var-namespace=${namespace}') :
           'with multi-select variables, `var-namespace=${namespace}` passes `{a,b}` as a single namespace to the Pod dashboard.\nGot: %s' % url;
    'PASS: gauges, table and drill-down link use OTel labels and multi-select variables',

  testDirectionMatchesPanel:
    local failures = [
      name
      for name in bandwidthQueries
      if !std.member(namespaceByPod[name](config), 'direction="%s"' % (if std.member(std.asciiLower(name), 'receive') then 'receive' else 'transmit'))
    ];
    assert failures == [] :
           'receive/transmit panels share one OTel metric split by direction; a swapped direction is a silent correctness bug.\nWrong direction: %s' % std.join(', ', failures);
    'PASS: each query filters on the direction of its panel',

  testInterfacesSummedNotDeduplicated:
    local queries = [namespaceByPod[name](config) for name in bandwidthQueries];
    assert std.all([std.member(q, 'k8s_pod_name, interface)') for q in queries]) :
           'dedup must keep `interface`, or a multi-interface pod shows only its busiest interface instead of the total.\nGot:\n%s' % std.toString(queries);
    'PASS: network queries sum across interfaces',

  testUnmappedPanelsReturnZero:
    local mapped = bandwidthQueries;
    local failures = [
      name
      for name in std.objectFieldsAll(namespaceByPod)
      if !std.member(mapped, name) && namespaceByPod[name](config) != '0'
    ];
    assert failures == [] :
           'kubeletstats has no packet or dropped-packet metric; k8s.pod.network.errors is not a substitute for drops.\nNot 0: %s' % std.join(', ', failures);
    'PASS: unmapped packet panels return 0',

  testCustomAttributesApplied:
    local queries = [namespaceByPod.gaugeReceiveBandwidth(configWithCustomAttributes), namespaceByPod.receiveBandwidth(configWithCustomAttributes)];
    assert std.all([std.member(q, 'env="prod"') && std.member(q, 'direction="receive"') for q in queries]) :
           'customAttributes must merge with the direction attribute.\nGot:\n%s' % std.toString(queries);
    'PASS: customAttributes applied alongside direction',
}
