// queries path must match the path in the kubernetes-mixin template
//
// Metrics come from the kubeletstats receiver `pod` metric group, which only
// reports network at pod level, with a `direction` attribute instead of
// separate receive/transmit metrics.
//
// Packet and dropped-packet counts have no OTel equivalent (see
// docs/otel-mapping.md), so those panels return '0'.
local commonQueries = import '../../resources/queries/common.libsonnet';
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

// Upstream reports bandwidth in bits by default (config.units.networkMultiplier).
local bandwidth(dir, config) =
  promql.mul({
    left: commonQueries.rateSumPodNetwork('k8s_pod_network_io_bytes_total', values, by=['k8s_pod_name'], attributes=direction(dir), config=config),
    right: std.toString(config.units.networkMultiplier),
  });

{
  // Upstream's gauges have no `by` because its pod variable is single-select;
  // ours is multi-select, so group by pod to get one gauge per selected pod.
  gaugeReceiveBandwidth(config)::
    bandwidth('receive', config),

  gaugeTransmitBandwidth(config)::
    bandwidth('transmit', config),

  receiveBandwidth(config)::
    bandwidth('receive', config),

  transmitBandwidth(config)::
    bandwidth('transmit', config),

  receivePackets(config)::
    '0',

  transmitPackets(config)::
    '0',

  receivePacketsDropped(config)::
    '0',

  transmitPacketsDropped(config)::
    '0',
}
