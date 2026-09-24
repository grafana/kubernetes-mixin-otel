local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local queries = import '../queries/common.libsonnet';
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

  cluster(config, datasourceVar)::
    var.query.new('cluster')
    + var.query.withDatasourceFromVariable(datasourceVar)
    + var.query.queryTypes.withLabelValues(
      'k8s_cluster_name',
      queries.selector('k8s_node_condition_ready', {}, extraAttributes=config.extraAttributes),
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

  node(config, datasourceVar)::
    var.query.new('node')
    + var.query.withDatasourceFromVariable(datasourceVar)
    + var.query.queryTypes.withLabelValues(
      'k8s_node_name',
      queries.selector('k8s_node_condition_ready', {}, extraAttributes=config.extraAttributes),
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

  namespace(config, datasourceVar)::
    var.query.new('namespace')
    + var.query.withDatasourceFromVariable(datasourceVar)
    + var.query.queryTypes.withLabelValues(
      'k8s_namespace_name',
      queries.selector('k8s_namespace_phase', {}, extraAttributes=config.extraAttributes),
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

  pod(config, datasourceVar)::
    var.query.new('pod')
    + var.query.withDatasourceFromVariable(datasourceVar)
    + var.query.queryTypes.withLabelValues(
      'k8s_pod_name',
      queries.selector('k8s_pod_phase', {}, extraAttributes=config.extraAttributes),
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
