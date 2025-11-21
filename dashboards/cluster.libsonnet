local kubernetes = import 'github.com/grafana/kubernetes-mixin/mixin.libsonnet';

// Configure the mixin (you can customize these values as needed)
local mixin = kubernetes {
  _config+:: {
    // Datasource configuration
    datasourceName: 'prometheus',
    datasourceFilterRegex: '.*',
    
    // Cluster configuration
    clusterLabel: 'cluster',
    namespaceLabel: 'namespace',
    showMultiCluster: false,
    
    // Prometheus job selectors - adjust these to match your setup
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    cadvisorSelector: 'job="cadvisor"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeletSelector: 'job="kubelet"',
  },
};

// Export the cluster dashboard from kubernetes-mixin
mixin.grafanaDashboards['k8s-resources-cluster.json']

