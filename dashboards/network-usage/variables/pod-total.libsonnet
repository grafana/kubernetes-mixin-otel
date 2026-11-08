// variables path must match the path in the kubernetes-mixin template
local commonVariables = import '../../resources/variables/common.libsonnet';

{
  podTotal(config)::
    local datasource = commonVariables.datasource(config);

    {
      datasource: datasource,
      cluster: commonVariables.cluster(datasource, config),
      namespace: commonVariables.namespace(datasource, config),
      pod: commonVariables.pod(datasource, config),
    },
}
