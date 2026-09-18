local pv = import '../dashboards/queries/persistentvolumesusage.libsonnet';

local config = {
  _config: {},
};

local expectedSpaceUsed =
  'max(k8s_volume_capacity_bytes{k8s_cluster_name="$cluster", k8s_namespace_name="$namespace", k8s_persistentvolumeclaim_name="$volume"}) - max(k8s_volume_available_bytes{k8s_cluster_name="$cluster", k8s_namespace_name="$namespace", k8s_persistentvolumeclaim_name="$volume"})';

local expectedInodesPercent =
  'max(k8s_volume_inodes_used_ratio{k8s_cluster_name="$cluster", k8s_namespace_name="$namespace", k8s_persistentvolumeclaim_name="$volume"}) / max(k8s_volume_inodes_ratio{k8s_cluster_name="$cluster", k8s_namespace_name="$namespace", k8s_persistentvolumeclaim_name="$volume"}) * 100';

{
  testVolumeSpaceUsageUsed:
    local result = pv.volumeSpaceUsageUsed(config);
    assert result == expectedSpaceUsed :
           'volumeSpaceUsageUsed failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedSpaceUsed, result];
    'PASS: volumeSpaceUsageUsed',

  testVolumeInodesUsagePercent:
    local result = pv.volumeInodesUsagePercent(config);
    assert result == expectedInodesPercent :
           'volumeInodesUsagePercent failed.\nExpected:\n%s\n\nGot:\n%s' % [expectedInodesPercent, result];
    'PASS: volumeInodesUsagePercent',

  testAllQueriesImplemented:
    local queries = [
      pv.volumeSpaceUsageUsed(config),
      pv.volumeSpaceUsageFree(config),
      pv.volumeSpaceUsagePercent(config),
      pv.volumeInodesUsageUsed(config),
      pv.volumeInodesUsageFree(config),
      pv.volumeInodesUsagePercent(config),
    ];
    assert std.all([q != null && q != '' && q != '0' for q in queries]) :
           'Some persistent volume queries are not implemented';
    'PASS: all 6 persistent volume queries implemented',
}
