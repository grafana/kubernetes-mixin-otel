local commonVariables = import './common.libsonnet';

{
  namespace(config)::
    local datasource = commonVariables.datasource(config);
    local clusterVar = commonVariables.cluster(datasource, config);
    {
      datasource: datasource,
      cluster: clusterVar,
      namespace: commonVariables.namespace(datasource, config),
    },
}
