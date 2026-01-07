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

  cluster(datasource)::
    var.query.new('cluster')
    + var.query.withDatasourceFromVariable(datasource)
    + var.query.queryTypes.withLabelValues(
      'k8s_cluster_name',
      'k8s_node_condition_ready',
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
  
  node(datasource)::
    var.query.new('node')
    + var.query.withDatasourceFromVariable(datasource)
    + var.query.queryTypes.withLabelValues(
      'k8s_node_name',
      'k8s_node_condition_ready',
    )
    + var.query.generalOptions.withLabel('node')
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

  namespace(datasource)::
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

  pod(datasource)::
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
}
