{
  // Minimal config for template-cluster.libsonnet dashboard
  // This includes only the properties actually used by template-cluster.libsonnet and its dependencies
  
  _config+:: {
    // Selectors used in Prometheus queries (required by cluster-k8s-queries.libsonnet)
    cadvisorSelector: 'job="cadvisor"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    containerfsSelector: 'container!=""',
    diskDeviceSelector: '',
    
    // Label names for cluster and namespace (required by queries and variables)
    clusterLabel: 'k8s_cluster_name',
    namespaceLabel: 'k8s_namespace_name',
    
    // Grafana dashboard configuration (required by template-cluster.libsonnet)
    grafanaK8s: {
      dashboardNamePrefix: '',
      dashboardTags: [],
      linkPrefix: '',
      refresh: '10s',
      minimumTimeInterval: '1m',
    },
    
    // Dashboard IDs (required for dashboard links in template-cluster.libsonnet)
    grafanaDashboardIDs: {
      'k8s-resources-cluster.json': std.md5('k8s-resources-cluster.json'),
      'k8s-resources-namespace.json': std.md5('k8s-resources-namespace.json'),
    },
    
    // Grafana interval variable (required by cluster-k8s-queries.libsonnet)
    grafana72: true,
    grafanaIntervalVar: if self.grafana72 then '$__rate_interval' else '$__interval',
    
    // Units for panels (required by template-cluster.libsonnet)
    units: {
      network: 'bps',
    },
    
    // Multi-cluster configuration (required by variables-k8s.libsonnet)
    showMultiCluster: false,
    
    // Datasource configuration (required by variables-k8s.libsonnet)
    datasourceName: 'prometheus',
    datasourceFilterRegex: '',
  },
}

