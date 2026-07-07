// variables path must match the path in the kubernetes-mixin template
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;
local commonVariables = import '../resources/variables/common.libsonnet';

// Single-select (not multi) mirrors the upstream kubernetes-mixin dashboard:
// the space/inodes gauges compute ratios for one PersistentVolumeClaim at a
// time and would be meaningless across several volumes.
//
// `k8s_persistentvolumeclaim_name!=""` restricts the variables to PVC-backed
// volumes; the kubeletstats `volume` metric group also reports configMap,
// secret and emptyDir volumes which have no PVC name.
{
  persistentVolume(config):: {
    datasource: commonVariables.datasource(config),

    cluster:
      var.query.new('cluster')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'k8s_cluster_name',
        'k8s_volume_capacity_bytes{k8s_persistentvolumeclaim_name!=""}',
      )
      + var.query.generalOptions.withLabel('cluster')
      + var.query.refresh.onTime()
      + (
        if config.showMultiCluster
        then var.query.generalOptions.showOnDashboard.withLabelAndValue()
        else var.query.generalOptions.showOnDashboard.withNothing()
      )
      + var.query.withSort(type='alphabetical'),

    namespace:
      var.query.new('namespace')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'k8s_namespace_name',
        'k8s_volume_capacity_bytes{k8s_cluster_name="$cluster", k8s_persistentvolumeclaim_name!=""}',
      )
      + var.query.generalOptions.withLabel('Namespace')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),

    volume:
      var.query.new('volume')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'k8s_persistentvolumeclaim_name',
        'k8s_volume_capacity_bytes{k8s_cluster_name="$cluster", k8s_namespace_name="$namespace"}',
      )
      + var.query.generalOptions.withLabel('PersistentVolumeClaim')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),
  },
}
