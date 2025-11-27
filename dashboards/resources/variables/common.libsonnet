local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;

{
  datasource(config)::
    var.datasource.new('datasource', 'prometheus')
    + var.datasource.withRegex(config.datasourceFilterRegex)
    + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
    + var.datasource.generalOptions.withLabel('Data source')
    + {
      current: {
        selected: true,
        text: config.datasourceName,
        value: config.datasourceName,
      },
    },

  // Cluster variable - Kubernetes cluster selector
  cluster(datasource)::
    var.query.new('cluster')
    + var.query.withDatasourceFromVariable(datasource)
    + var.query.queryTypes.withLabelValues(
      'k8s_cluster_name',
      'system_cpu_logical_count',
    )
    + var.query.generalOptions.withLabel('cluster')
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
}

