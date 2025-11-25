local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local table = g.panel.table;
local timeSeries = g.panel.timeSeries;

{
  // Main function to generate cluster dashboard with dynamic variables
  // Parameters:
  //   config: Configuration object (required)
  //   variablesLib: Variables library object (required)
  //   defaultQueries: Queries object (required)
  //   vars: Dashboard variables object (optional, will be generated if not provided)
  //   queries: Queries object (optional, will use defaultQueries if not provided)
  new(config, variablesLib, defaultQueries, vars=null, queries=null)::
    local dashboardVars = if vars != null then vars else variablesLib.clusterDashboard(config);
    local dashboardQueries = if queries != null then queries else defaultQueries;

    local statPanel(title, unit, query) =
      stat.new(title)
      + {
        datasource: {
          type: 'prometheus',
          uid: '${datasource}',
        },
      }
      + stat.options.withColorMode('none')
      + stat.standardOptions.withUnit(unit)
      + stat.queryOptions.withInterval(config.grafanaK8s.minimumTimeInterval)
      + stat.queryOptions.withTargets([
        prometheus.new('${datasource}', query)
        + prometheus.withInstant(true),
      ]);

    local tsPanel =
      timeSeries {
        new(title):
          timeSeries.new(title)
          + {
            datasource: {
              type: 'prometheus',
              uid: '${datasource}',
            },
          }
          + timeSeries.options.legend.withShowLegend()
          + timeSeries.options.legend.withAsTable()
          + timeSeries.options.legend.withDisplayMode('table')
          + timeSeries.options.legend.withPlacement('right')
          + timeSeries.options.legend.withCalcs(['lastNotNull'])
          + timeSeries.options.tooltip.withMode('single')
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
          + timeSeries.fieldConfig.defaults.custom.withSpanNulls(true)
          + timeSeries.queryOptions.withInterval(config.grafanaK8s.minimumTimeInterval),
      };

    local links = {
      namespace: {
        title: 'Drill down to pods',
        url: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?${datasource:queryparam}&var-cluster=$cluster&var-namespace=${__data.fields.Namespace}' % {
          uid: config.grafanaDashboardIDs['k8s-resources-namespace.json'],
          prefix: config.grafanaK8s.linkPrefix,
        },
      },
    };

    local panels = [
      statPanel(
        'CPU Utilisation',
        'percentunit',
        dashboardQueries.statQueries.cpuUtilisation(config)
      )
      + stat.gridPos.withW(4)
      + stat.gridPos.withH(3),

      statPanel(
        'CPU Requests Commitment',
        'percentunit',
        dashboardQueries.statQueries.cpuRequestsCommitment(config)
      )
      + stat.gridPos.withW(4)
      + stat.gridPos.withH(3),

      statPanel(
        'CPU Limits Commitment',
        'percentunit',
        dashboardQueries.statQueries.cpuLimitsCommitment(config)
      )
      + stat.gridPos.withW(4)
      + stat.gridPos.withH(3),

      statPanel(
        'Memory Utilisation',
        'percentunit',
        dashboardQueries.statQueries.memoryUtilisation(config)
      )
      + stat.gridPos.withW(4)
      + stat.gridPos.withH(3),

      statPanel(
        'Memory Requests Commitment',
        'percentunit',
        dashboardQueries.statQueries.memoryRequestsCommitment(config)
      )
      + stat.gridPos.withW(4)
      + stat.gridPos.withH(3),

      statPanel(
        'Memory Limits Commitment',
        'percentunit',
        dashboardQueries.statQueries.memoryLimitsCommitment(config)
      )
      + stat.gridPos.withW(4)
      + stat.gridPos.withH(3),

      tsPanel.new('CPU Usage')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.cpuUsage(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      table.new('CPU Quota')
      + {
        datasource: {
          type: 'prometheus',
          uid: '${datasource}',
        },
      }
      + table.queryOptions.withTargets([
        prometheus.new('${datasource}', dashboardQueries.tableQueries.cpuQuota.pods(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.cpuQuota.workloads(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.cpuQuota.cpuUsage(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.cpuQuota.cpuRequests(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.cpuQuota.cpuRequestsPercent(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.cpuQuota.cpuLimits(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.cpuQuota.cpuLimitsPercent(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),
      ])

      + table.queryOptions.withTransformations([
        table.queryOptions.transformation.withId('joinByField')
        + table.queryOptions.transformation.withOptions({
          byField: 'namespace',
          mode: 'outer',
        }),

        table.queryOptions.transformation.withId('organize')
        + table.queryOptions.transformation.withOptions({
          excludeByName: {
            Time: true,
            'Time 1': true,
            'Time 2': true,
            'Time 3': true,
            'Time 4': true,
            'Time 5': true,
            'Time 6': true,
            'Time 7': true,
          },
          indexByName: {
            'Time 1': 0,
            'Time 2': 1,
            'Time 3': 2,
            'Time 4': 3,
            'Time 5': 4,
            'Time 6': 5,
            'Time 7': 6,
            namespace: 7,
            'Value #A': 8,
            'Value #B': 9,
            'Value #C': 10,
            'Value #D': 11,
            'Value #E': 12,
            'Value #F': 13,
            'Value #G': 14,
          },
          renameByName: {
            namespace: 'Namespace',
            'Value #A': 'Pods',
            'Value #B': 'Workloads',
            'Value #C': 'CPU Usage',
            'Value #D': 'CPU Requests',
            'Value #E': 'CPU Requests %',
            'Value #F': 'CPU Limits',
            'Value #G': 'CPU Limits %',
          },
        }),
      ])

      + table.standardOptions.withOverrides([
        {
          matcher: {
            id: 'byRegexp',
            options: '/%/',
          },
          properties: [
            {
              id: 'unit',
              value: 'percentunit',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Namespace',
          },
          properties: [
            {
              id: 'links',
              value: [links.namespace],
            },
          ],
        },
      ]),

      tsPanel.new('Memory')
      + tsPanel.standardOptions.withUnit('bytes')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.memory(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      table.new('Memory Requests by Namespace')
      + {
        datasource: {
          type: 'prometheus',
          uid: '${datasource}',
        },
      }
      + table.queryOptions.withTargets([
        prometheus.new('${datasource}', dashboardQueries.tableQueries.memoryRequests.pods(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.memoryRequests.workloads(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.memoryRequests.memoryUsage(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.memoryRequests.memoryRequests(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.memoryRequests.memoryRequestsPercent(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.memoryRequests.memoryLimits(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.memoryRequests.memoryLimitsPercent(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),
      ])

      + table.queryOptions.withTransformations([
        table.queryOptions.transformation.withId('joinByField')
        + table.queryOptions.transformation.withOptions({
          byField: 'namespace',
          mode: 'outer',
        }),

        table.queryOptions.transformation.withId('organize')
        + table.queryOptions.transformation.withOptions({
          excludeByName: {
            Time: true,
            'Time 1': true,
            'Time 2': true,
            'Time 3': true,
            'Time 4': true,
            'Time 5': true,
            'Time 6': true,
            'Time 7': true,
          },
          indexByName: {
            'Time 1': 0,
            'Time 2': 1,
            'Time 3': 2,
            'Time 4': 3,
            'Time 5': 4,
            'Time 6': 5,
            'Time 7': 6,
            namespace: 7,
            'Value #A': 8,
            'Value #B': 9,
            'Value #C': 10,
            'Value #D': 11,
            'Value #E': 12,
            'Value #F': 13,
            'Value #G': 14,
          },
          renameByName: {
            namespace: 'Namespace',
            'Value #A': 'Pods',
            'Value #B': 'Workloads',
            'Value #C': 'Memory Usage',
            'Value #D': 'Memory Requests',
            'Value #E': 'Memory Requests %',
            'Value #F': 'Memory Limits',
            'Value #G': 'Memory Limits %',
          },
        }),
      ])

      + table.standardOptions.withOverrides([
        {
          matcher: {
            id: 'byRegexp',
            options: '/%/',
          },
          properties: [
            {
              id: 'unit',
              value: 'percentunit',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Memory Usage',
          },
          properties: [
            {
              id: 'unit',
              value: 'bytes',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Memory Requests',
          },
          properties: [
            {
              id: 'unit',
              value: 'bytes',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Memory Limits',
          },
          properties: [
            {
              id: 'unit',
              value: 'bytes',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Namespace',
          },
          properties: [
            {
              id: 'links',
              value: [links.namespace],
            },
          ],
        },
      ]),

      table.new('Current Network Usage')
      + {
        datasource: {
          type: 'prometheus',
          uid: '${datasource}',
        },
      }
      + table.queryOptions.withTargets([
        prometheus.new('${datasource}', dashboardQueries.tableQueries.networkUsage.receiveBandwidth(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.networkUsage.transmitBandwidth(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.networkUsage.receivePackets(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.networkUsage.transmitPackets(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.networkUsage.receivePacketsDropped(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.networkUsage.transmitPacketsDropped(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),
      ])

      + table.queryOptions.withTransformations([
        table.queryOptions.transformation.withId('joinByField')
        + table.queryOptions.transformation.withOptions({
          byField: 'namespace',
          mode: 'outer',
        }),

        table.queryOptions.transformation.withId('organize')
        + table.queryOptions.transformation.withOptions({
          excludeByName: {
            Time: true,
            'Time 1': true,
            'Time 2': true,
            'Time 3': true,
            'Time 4': true,
            'Time 5': true,
            'Time 6': true,
          },
          indexByName: {
            'Time 1': 0,
            'Time 2': 1,
            'Time 3': 2,
            'Time 4': 3,
            'Time 5': 4,
            'Time 6': 5,
            namespace: 6,
            'Value #A': 7,
            'Value #B': 8,
            'Value #C': 9,
            'Value #D': 10,
            'Value #E': 11,
            'Value #F': 12,
          },
          renameByName: {
            namespace: 'Namespace',
            'Value #A': 'Current Receive Bandwidth',
            'Value #B': 'Current Transmit Bandwidth',
            'Value #C': 'Rate of Received Packets',
            'Value #D': 'Rate of Transmitted Packets',
            'Value #E': 'Rate of Received Packets Dropped',
            'Value #F': 'Rate of Transmitted Packets Dropped',
          },
        }),
      ])

      + table.standardOptions.withOverrides([
        {
          matcher: {
            id: 'byRegexp',
            options: '/Bandwidth/',
          },
          properties: [
            {
              id: 'unit',
              value: config.units.network,
            },
          ],
        },
        {
          matcher: {
            id: 'byRegexp',
            options: '/Packets/',
          },
          properties: [
            {
              id: 'unit',
              value: 'pps',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Namespace',
          },
          properties: [
            {
              id: 'links',
              value: [links.namespace],
            },
          ],
        },
      ]),

      tsPanel.new('Receive Bandwidth')
      + tsPanel.standardOptions.withUnit(config.units.network)
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.receiveBandwidth(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('Transmit Bandwidth')
      + tsPanel.standardOptions.withUnit(config.units.network)
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.transmitBandwidth(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('Average Container Bandwidth by Namespace: Received')
      + tsPanel.standardOptions.withUnit(config.units.network)
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.avgReceiveBandwidth(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('Average Container Bandwidth by Namespace: Transmitted')
      + tsPanel.standardOptions.withUnit(config.units.network)
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.avgTransmitBandwidth(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('Rate of Received Packets')
      + tsPanel.standardOptions.withUnit('pps')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.rateReceivedPackets(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('Rate of Transmitted Packets')
      + tsPanel.standardOptions.withUnit('pps')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.rateTransmittedPackets(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('Rate of Received Packets Dropped')
      + tsPanel.standardOptions.withUnit('pps')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.rateReceivedPacketsDropped(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('Rate of Transmitted Packets Dropped')
      + tsPanel.standardOptions.withUnit('pps')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.rateTransmittedPacketsDropped(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('IOPS(Reads+Writes)')
      + tsPanel.standardOptions.withUnit('iops')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.iopsReadsWrites(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      tsPanel.new('ThroughPut(Read+Write)')
      + tsPanel.standardOptions.withUnit('Bps')
      + tsPanel.queryOptions.withTargets([
        prometheus.new(
          '${datasource}',
          dashboardQueries.timeSeriesQueries.throughputReadWrite(config)
        )
        + prometheus.withLegendFormat('__auto'),
      ]),

      table.new('Current Storage IO')
      + {
        datasource: {
          type: 'prometheus',
          uid: '${datasource}',
        },
      }
      + table.queryOptions.withTargets([
        prometheus.new('${datasource}', dashboardQueries.tableQueries.storageIO.readsIOPS(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.storageIO.writesIOPS(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.storageIO.totalIOPS(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.storageIO.readThroughput(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.storageIO.writeThroughput(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),

        prometheus.new('${datasource}', dashboardQueries.tableQueries.storageIO.totalThroughput(config))
        + prometheus.withInstant(true)
        + prometheus.withFormat('table'),
      ])

      + table.queryOptions.withTransformations([
        table.queryOptions.transformation.withId('joinByField')
        + table.queryOptions.transformation.withOptions({
          byField: 'namespace',
          mode: 'outer',
        }),

        table.queryOptions.transformation.withId('organize')
        + table.queryOptions.transformation.withOptions({
          excludeByName: {
            Time: true,
            'Time 1': true,
            'Time 2': true,
            'Time 3': true,
            'Time 4': true,
            'Time 5': true,
            'Time 6': true,
          },
          indexByName: {
            'Time 1': 0,
            'Time 2': 1,
            'Time 3': 2,
            'Time 4': 3,
            'Time 5': 4,
            'Time 6': 5,
            namespace: 6,
            'Value #A': 7,
            'Value #B': 8,
            'Value #C': 9,
            'Value #D': 10,
            'Value #E': 11,
            'Value #F': 12,
          },
          renameByName: {
            namespace: 'Namespace',
            'Value #A': 'IOPS(Reads)',
            'Value #B': 'IOPS(Writes)',
            'Value #C': 'IOPS(Reads + Writes)',
            'Value #D': 'Throughput(Read)',
            'Value #E': 'Throughput(Write)',
            'Value #F': 'Throughput(Read + Write)',
          },
        }),
      ])

      + table.standardOptions.withOverrides([
        {
          matcher: {
            id: 'byRegexp',
            options: '/IOPS/',
          },
          properties: [
            {
              id: 'unit',
              value: 'iops',
            },
          ],
        },
        {
          matcher: {
            id: 'byRegexp',
            options: '/Throughput/',
          },
          properties: [
            {
              id: 'unit',
              value: config.units.network,
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Namespace',
          },
          properties: [
            {
              id: 'links',
              value: [links.namespace],
            },
          ],
        },
      ]),
    ];

    g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Cluster' % config.grafanaK8s)
    + g.dashboard.withUid(config.grafanaDashboardIDs['k8s-resources-cluster.json'])
    + g.dashboard.withTags(config.grafanaK8s.dashboardTags)
    + g.dashboard.withEditable(false)
    + g.dashboard.time.withFrom('now-1h')
    + g.dashboard.time.withTo('now')
    + g.dashboard.withRefresh(config.grafanaK8s.refresh)
    + g.dashboard.withVariables([dashboardVars.datasource, dashboardVars.cluster])
    + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=6)),

  // Backward compatibility: maintain the existing interface (only if _config exists)
  grafanaDashboards:: (
    if std.objectHas($, '_config') then
      local variablesLib = import '../variables/variables-k8s.libsonnet';
      local defaultQueries = import '../queries/cluster-k8s-queries.libsonnet';
      {
        'k8s-resources-cluster.json': $.new($._config, variablesLib, defaultQueries),
      }
    else {}
  ),
}
