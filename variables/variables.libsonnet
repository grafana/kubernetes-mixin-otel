local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;

local datasourceVar =
  var.datasource.new('datasource', 'prometheus')
  + {
    current: {
      selected: true,
      text: 'Prometheus',
      value: 'prometheus',
    },
  };

{
  variables: {
    datasource: datasourceVar,

    cluster:
      var.query.new('cluster')
      + var.query.withDatasourceFromVariable(datasourceVar)
      + var.query.queryTypes.withLabelValues(
        'k8s_cluster_name',
        'system_cpu_logical_count',
      )
      + var.query.generalOptions.withLabel('cluster')
      + var.query.selectionOptions.withIncludeAll(true)
      + var.query.selectionOptions.withMulti(true)
      + var.query.refresh.onTime()
      + var.query.withSort(type='alphabetical')
      + {
        current: {
          selected: true,
          text: 'All',
          value: '$__all',
        },
      },

    namespace:
      var.query.new('namespace')
      + var.query.withDatasourceFromVariable(datasourceVar)
      + var.query.queryTypes.withLabelValues(
        'k8s_namespace_name',
        'k8s_namespace_phase{k8s_cluster_name=~"${cluster:pipe}"}',
      )
      + var.query.generalOptions.withLabel('namespace')
      + var.query.selectionOptions.withIncludeAll(true)
      + var.query.selectionOptions.withMulti(true)
      + var.query.refresh.onTime()
      + var.query.withSort(type='alphabetical')
      + {
        current: {
          selected: true,
          text: 'All',
          value: '$__all',
        },
      },
  },
}

