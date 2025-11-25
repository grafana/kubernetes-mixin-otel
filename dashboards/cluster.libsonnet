local templateCluster = import './template-cluster.libsonnet';
local config = import './config.libsonnet';
local variables = import '../variables/variables.libsonnet';
local queries = import '../queries/cluster-queries.libsonnet';

// Create a minimal variablesLib object that has a clusterDashboard function
// Since variables.libsonnet doesn't have clusterDashboard, we'll pass vars directly
local variablesLib = {
  clusterDashboard(config)::
    variables.variables,
};

{
  grafanaDashboards+:: {
    'cluster.json': templateCluster.new(
      config._config,
      variablesLib,
      queries,
      vars=variables.variables,
      queries=queries
    ),
  },
}
