// queries path must match the path in the kubernetes-mixin template
//
// Metrics come from the kubeletstats receiver `volume` metric group:
// https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/kubeletstatsreceiver/documentation.md
//
// Naming notes:
// - `k8s.volume.available` / `k8s.volume.capacity` (unit: By) are exported to
//   Prometheus as `k8s_volume_available_bytes` / `k8s_volume_capacity_bytes`.
// - `k8s.volume.inodes` / `k8s.volume.inodes.used` (unit: 1) gain a `_ratio`
//   suffix from the Prometheus OTLP translation of dimensionless gauges, so
//   they are queried as `k8s_volume_inodes_ratio` / `k8s_volume_inodes_used_ratio`
//   despite being absolute inode counts.
//
// The `k8s_persistentvolumeclaim_name` label requires the kubeletstats
// receiver option `extra_metadata_labels: [k8s.volume.type]`.
//
// `max()` collapses per-pod/per-node label noise (job, instance,
// k8s_pod_name, ...) and deduplicates repeated reports of the same PVC,
// mirroring the `sum without(...) (topk(1, ...))` pattern used upstream.
{
  local filters = 'k8s_cluster_name="$cluster", k8s_namespace_name="$namespace", k8s_persistentvolumeclaim_name="$volume"',

  // Volume Space Usage
  volumeSpaceUsageUsed(config)::
    'max(k8s_volume_capacity_bytes{%(filters)s}) - max(k8s_volume_available_bytes{%(filters)s})' % { filters: filters },

  volumeSpaceUsageFree(config)::
    'max(k8s_volume_available_bytes{%(filters)s})' % { filters: filters },

  volumeSpaceUsagePercent(config)::
    '(max(k8s_volume_capacity_bytes{%(filters)s}) - max(k8s_volume_available_bytes{%(filters)s})) / max(k8s_volume_capacity_bytes{%(filters)s}) * 100' % { filters: filters },

  // Volume inodes Usage
  volumeInodesUsageUsed(config)::
    'max(k8s_volume_inodes_used_ratio{%(filters)s})' % { filters: filters },

  volumeInodesUsageFree(config)::
    'max(k8s_volume_inodes_ratio{%(filters)s}) - max(k8s_volume_inodes_used_ratio{%(filters)s})' % { filters: filters },

  volumeInodesUsagePercent(config)::
    'max(k8s_volume_inodes_used_ratio{%(filters)s}) / max(k8s_volume_inodes_ratio{%(filters)s}) * 100' % { filters: filters },
}
