local commonVariables = import './common.libsonnet';

{
  pod(config)::
    local datasource = commonVariables.datasource(config);

    {
      datasource: datasource,
      cluster: commonVariables.cluster(config, datasource),
      namespace: commonVariables.namespace(config, datasource),
      pod: commonVariables.pod(config, datasource),
    },
}
