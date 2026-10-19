local commonVariables = import './common.libsonnet';

{
  pod(config)::
    local datasource = commonVariables.datasource(config);

    {
      datasource: datasource,
      cluster: commonVariables.cluster(datasource, config),
      namespace: commonVariables.namespace(datasource, config),
      pod: commonVariables.pod(datasource, config),
    },
}
