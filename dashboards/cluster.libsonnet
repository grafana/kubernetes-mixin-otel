local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

{
  grafanaDashboards+:: {
    'cluster.json':
      local variables = {
        datasource:
          var.datasource.new('datasource', 'prometheus')
          + {
            current: {
              selected: true,
              text: 'Prometheus',
              value: 'prometheus',
            },
          },

        cluster:
          var.query.new('cluster')
          + var.query.withDatasourceFromVariable(self.datasource)
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
          + var.query.withDatasourceFromVariable(self.datasource)
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
      };

      local panels = [
        timeSeries.new('CPU Usage')
        + {
          datasource: {
            type: 'prometheus',
            uid: '${datasource}',
          },
        }
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withDisplayMode('list')
        + timeSeries.options.legend.withPlacement('bottom')
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(0)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('auto')
        + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
        + timeSeries.standardOptions.withUnit('cores')
        + timeSeries.standardOptions.thresholds.withMode('absolute')
        + timeSeries.standardOptions.thresholds.withSteps([
          timeSeries.thresholdStep.withColor('green')
          + timeSeries.thresholdStep.withValue(0),
          timeSeries.thresholdStep.withColor('red')
          + timeSeries.thresholdStep.withValue(80),
        ])
        + timeSeries.gridPos.withW(12)
        + timeSeries.gridPos.withH(8)
        + timeSeries.gridPos.withX(0)
        + timeSeries.gridPos.withY(0)
        + timeSeries.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by (k8s_cluster_name, k8s_namespace_name)(
                k8s_container_cpu_request{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"}
            )'
          )
          + prometheus.withLegendFormat('requests: {{k8s_cluster_name}} - {{k8s_namespace_name}}'),
        ]),

        timeSeries.new('Memory Usage')
        + {
          datasource: {
            type: 'prometheus',
            uid: '${datasource}',
          },
        }
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withDisplayMode('list')
        + timeSeries.options.legend.withPlacement('bottom')
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(0)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('auto')
        + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
        + timeSeries.standardOptions.withUnit('bytes')
        + timeSeries.standardOptions.thresholds.withMode('absolute')
        + timeSeries.standardOptions.thresholds.withSteps([
          timeSeries.thresholdStep.withColor('green')
          + timeSeries.thresholdStep.withValue(0),
          timeSeries.thresholdStep.withColor('red')
          + timeSeries.thresholdStep.withValue(80),
        ])
        + timeSeries.gridPos.withW(12)
        + timeSeries.gridPos.withH(8)
        + timeSeries.gridPos.withX(12)
        + timeSeries.gridPos.withY(0)
        + timeSeries.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by (k8s_cluster_name) (
                k8s_container_memory_request_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"}
            )'
          )
          + prometheus.withLegendFormat('requests: {{k8s_cluster_name}}'),
          prometheus.new(
            '${datasource}',
            'sum by (k8s_cluster_name) (
                k8s_container_memory_limit_bytes{k8s_cluster_name=~"${cluster:pipe}", k8s_namespace_name=~"${namespace:pipe}"}
            )'
          )
          + prometheus.withLegendFormat('limit: {{k8s_cluster_name}}'),
        ]),
      ];

      g.dashboard.new('Cluster')
      + g.dashboard.withEditable(true)
      + g.dashboard.time.withFrom('now-12h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace])
      + g.dashboard.withPanels(panels),
  },
}
