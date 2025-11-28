local commonVariables = import './common.libsonnet';

{
  pod(config)::
    local datasource = commonVariables.datasource(config);

    {
      datasource: datasource,
      cluster: commonVariables.cluster(datasource),
      namespace: commonVariables.namespace(datasource),
      pod: commonVariables.pod(datasource),
    },
}
