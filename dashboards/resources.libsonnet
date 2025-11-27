local cluster = import 'resources/cluster.libsonnet';
local pod = import 'resources/pod.libsonnet';

{
  grafanaDashboards: cluster.grafanaDashboards + pod.grafanaDashboards,
}
