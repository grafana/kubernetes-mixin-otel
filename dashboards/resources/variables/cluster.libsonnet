local commonVariables = import './common.libsonnet';

{
  // Cluster dashboard variables
  // Returns datasource and cluster variables
  cluster(config)::
    local datasource = commonVariables.datasource(config);

    {
      datasource: datasource,
      cluster: commonVariables.cluster(datasource),
    },
}
