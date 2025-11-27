local commonVariables = import './common.libsonnet';

{
  cluster(config)::
    local datasource = commonVariables.datasource(config);

    {
      datasource: datasource,
      cluster: commonVariables.cluster(datasource),
    },
}
