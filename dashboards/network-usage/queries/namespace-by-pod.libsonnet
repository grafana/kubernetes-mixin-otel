// queries path must match the path in the kubernetes-mixin template
//
// Metrics come from the kubeletstats receiver `pod` metric group, which only
// reports network at pod level, with a `direction` attribute instead of
// separate receive/transmit metrics.
//
// Packet and dropped-packet counts have no OTel equivalent (see
// docs/otel-mapping.md), so those panels return '0'. Upstream's
// host_network="false" filter has no OTel equivalent either, so host-network
// pods show their node's traffic.
local commonQueries = import '../../resources/queries/common.libsonnet';
local tsqtsq = import 'github.com/grafana/tsqtsq/jsonnet/promql.libsonnet';

local promql = tsqtsq.promql;

local values = {
  k8s_cluster_name: '${cluster:pipe}',
  k8s_namespace_name: '${namespace:pipe}',
};

local direction(value) = [
  { label: 'direction', operator: tsqtsq.MatchingOperator.equal, value: value },
];

// Upstream reports bandwidth in bits by default (config.units.networkMultiplier).
local bandwidth(dir, by, config) =
  promql.mul({
    left: commonQueries.rateSumPodNetwork('k8s_pod_network_io_bytes_total', values, by=by, attributes=direction(dir), config=config),
    right: std.toString(config.units.networkMultiplier),
  });

{
  // Upstream's gauges have no `by` because its namespace variable is
  // single-select; ours is multi-select, so group by namespace.
  gaugeReceiveBandwidth(config)::
    bandwidth('receive', ['k8s_namespace_name'], config),

  gaugeTransmitBandwidth(config)::
    bandwidth('transmit', ['k8s_namespace_name'], config),

  // The Current Network Usage table joins these on k8s_pod_name.
  receiveBandwidth(config)::
    bandwidth('receive', ['k8s_pod_name'], config),

  transmitBandwidth(config)::
    bandwidth('transmit', ['k8s_pod_name'], config),

  receivePackets(config)::
    '0',

  transmitPackets(config)::
    '0',

  receivePacketsDropped(config)::
    '0',

  transmitPacketsDropped(config)::
    '0',

  receivePacketsDroppedTimeSeries(config)::
    '0',
}
