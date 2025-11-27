local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;
local commonVariables = import './common.libsonnet';

{
  pod(config)::
    local datasource = commonVariables.datasource(config);

    {
      datasource: datasource,
      cluster: commonVariables.cluster(datasource),
      namespace:
        var.query.new('namespace')
        + var.query.withDatasourceFromVariable(datasource)
        + var.query.queryTypes.withLabelValues(
          'k8s_namespace_name',
          'k8s_namespace_phase',
        )
        + var.query.generalOptions.withLabel('namespace')
        + var.query.selectionOptions.withIncludeAll(true)
        + var.query.selectionOptions.withMulti(true)
        + var.query.refresh.onTime()
        + var.query.generalOptions.showOnDashboard.withLabelAndValue()
        + var.query.withSort(type='alphabetical')
        + {
          allowCustom: false,
          current: {
            selected: true,
            text: 'All',
            value: '$__all',
          },
        },
      pod:
        var.query.new('pod')
        + var.query.withDatasourceFromVariable(datasource)
        + var.query.queryTypes.withLabelValues(
          'k8s_pod_name',
          'k8s_pod_phase',
        )
        + var.query.generalOptions.withLabel('pod')
        + var.query.selectionOptions.withIncludeAll(true)
        + var.query.selectionOptions.withMulti(true)
        + var.query.refresh.onTime()
        + var.query.generalOptions.showOnDashboard.withLabelAndValue()
        + var.query.withSort(type='alphabetical')
        + {
          allowCustom: false,
          current: {
            selected: true,
            text: 'All',
            value: '$__all',
          },
        },
    },
}
