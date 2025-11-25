local clusterK8s = import './template-cluster.libsonnet';
local config = import './config.libsonnet';
local variablesLib = import '../variables/variables-k8s.libsonnet';
local defaultQueries = import '../queries/cluster-k8s-queries.libsonnet';

{
  grafanaDashboards+:: {
    'k8s-resources-cluster.json': clusterK8s.new(config._config, variablesLib, defaultQueries),
  },
}

