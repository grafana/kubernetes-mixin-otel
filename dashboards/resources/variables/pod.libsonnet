local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;

{
  // Pod dashboard variables
  // Returns datasource, cluster, namespace, and pod variables
  pod(config)::
    local datasource =
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
      };

    local clusterVar =
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
      };

    {
      datasource: datasource,
      cluster: clusterVar,
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
