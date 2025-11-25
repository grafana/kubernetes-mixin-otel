local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;

{
  // Base datasource variable used across all dashboards
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

  // Cluster variable with configurable selector
  cluster(config, selector)::
    var.query.new('cluster')
    + var.query.withDatasourceFromVariable(self.datasource(config))
    + var.query.queryTypes.withLabelValues(
      config.clusterLabel,
      selector,
    )
    + var.query.generalOptions.withLabel('cluster')
    + var.query.refresh.onTime()
    + (
      if config.showMultiCluster
      then var.query.generalOptions.showOnDashboard.withLabelAndValue()
      else var.query.generalOptions.showOnDashboard.withNothing()
    )
    + var.query.withSort(type='alphabetical'),

  // Convenience function to generate common cluster dashboard variables
  clusterDashboard(config):: 
    local datasourceVar = $.datasource(config);
    local clusterVar = $.cluster(config, 'up{%(cadvisorSelector)s}' % config);
    {
      datasource: datasourceVar,
      cluster: clusterVar,
    },

  // Convenience function to generate namespace dashboard variables
  namespaceDashboard(config):: 
    local datasourceVar = $.datasource(config);
    local clusterVar = $.cluster(config, 'up{%(kubeStateMetricsSelector)s}' % config);
    {
      datasource: datasourceVar,
      cluster: clusterVar,
      namespace:
        var.query.new('namespace')
        + var.query.withDatasourceFromVariable(datasourceVar)
        + var.query.queryTypes.withLabelValues(
          'namespace',
          'kube_namespace_status_phase{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}' % config,
        )
        + var.query.generalOptions.withLabel('namespace')
        + var.query.refresh.onTime()
        + var.query.generalOptions.showOnDashboard.withLabelAndValue()
        + var.query.withSort(type='alphabetical'),
    },
}

