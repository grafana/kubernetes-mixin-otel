// queries path must match the path in the kubernetes-mixin template
//
// Metrics come from the kubeletstats receiver `pod` metric group, which only
// reports network at pod level, with a `direction` attribute instead of
// separate receive/transmit metrics.
//
// - Packet counts have no OTel equivalent, so those panels return '0'.
// - Upstream "Packets Dropped" panels are backed by `k8s.pod.network.errors`,
//   the closest available signal, as in the Compute Resources / Pod dashboard.
local activePods = import '../../../lib/active_pods.libsonnet';
local grouping = import '../../../lib/grouping.libsonnet';
local selectors = import '../../../lib/selectors.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local values = {
  k8s_cluster_name: '${cluster:pipe}',
  k8s_namespace_name: '${namespace:pipe}',
  k8s_pod_name: '${pod:pipe}',
};

local direction(value) = [
  { label: 'direction', operator: tsqtsq.MatchingOperator.equal, value: value },
];

// Like commonQueries.rateSumPodLevel, but keeps `interface` in the dedup so a
// multi-interface pod reports the sum of its interfaces, as upstream does.
local rateSumAcrossInterfaces(metric, by, dir, config) =
  promql.sum({
    by: grouping.maybeWithGrouping(by, config),
    expr: promql.max({
      by: grouping.maybeWithGrouping(activePods.podMaxBy + ['interface'], config),
      expr: promql.rate({ expr: selectors.selector(metric, values, direction(dir), config=config) }),
    }),
  });

// Upstream reports bandwidth in bits by default (config.units.networkMultiplier).
local bandwidth(dir, by, config) =
  promql.mul({
    left: rateSumAcrossInterfaces('k8s_pod_network_io_bytes_total', by, dir, config),
    right: std.toString(config.units.networkMultiplier),
  });

{
  // Upstream's gauges have no `by` because its pod variable is single-select;
  // ours is multi-select, so group by pod to get one gauge per selected pod.
  gaugeReceiveBandwidth(config)::
    bandwidth('receive', ['k8s_pod_name'], config),

  gaugeTransmitBandwidth(config)::
    bandwidth('transmit', ['k8s_pod_name'], config),

  receiveBandwidth(config)::
    bandwidth('receive', ['k8s_pod_name'], config),

  transmitBandwidth(config)::
    bandwidth('transmit', ['k8s_pod_name'], config),

  receivePackets(config)::
    '0',

  transmitPackets(config)::
    '0',

  receivePacketsDropped(config)::
    rateSumAcrossInterfaces('k8s_pod_network_errors_total', ['k8s_pod_name'], 'receive', config),

  transmitPacketsDropped(config)::
    rateSumAcrossInterfaces('k8s_pod_network_errors_total', ['k8s_pod_name'], 'transmit', config),
}
