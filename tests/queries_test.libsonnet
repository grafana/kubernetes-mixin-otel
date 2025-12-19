// Test generation for OTel mixin queries
// This file generates promtool test YAML from the actual dashboard queries
// Run: jsonnet -J vendor tests/queries_test.libsonnet -o tests/queries_test.yaml

local cluster = import '../dashboards/resources/queries/cluster.libsonnet';
local namespace = import '../dashboards/resources/queries/namespace.libsonnet';
local pod = import '../dashboards/resources/queries/pod.libsonnet';

// Config object that queries expect
local config = { _config: {} };

// Replace Grafana variables with test values for promtool
local replaceVars(query) =
  std.strReplace(
    std.strReplace(
      std.strReplace(
        std.strReplace(query, '${cluster}', 'kubernetes-mixin-otel'),
        '${namespace}', 'default'
      ),
      '${pod}', 'nginx-abc123-xyz'
    ),
    '$__rate_interval', '5m'
  );

// Helper to strip trailing newlines and normalize whitespace
local normalizeQuery(query) =
  local trimmed = std.stripChars(query, '\n');
  // Also normalize internal whitespace for consistent output
  std.strReplace(trimmed, "'\n", "'");

// Test data generators for different scenarios
local testData = {
  // Common labels for nginx pod in default namespace
  nginxLabels: 'host_name="k3d-kubernetes-mixin-otel-server-0", instance="default.nginx-abc123-xyz.nginx", job="default/nginx", k8s_cluster_name="kubernetes-mixin-otel", k8s_container_name="nginx", k8s_deployment_name="nginx", k8s_namespace_name="default", k8s_node_name="k3d-kubernetes-mixin-otel-server-0", k8s_pod_name="nginx-abc123-xyz", k8s_replicaset_name="nginx-abc123", service_instance_id="default.nginx-abc123-xyz.nginx", service_name="nginx", service_namespace="default", service_version="1.25.0"',

  // Common labels for coredns pod in kube-system namespace
  corednsLabels: 'host_name="k3d-kubernetes-mixin-otel-server-0", instance="kube-system.coredns-576bfc4dc7-5xhx7.coredns", job="kube-system/coredns", k8s_cluster_name="kubernetes-mixin-otel", k8s_container_name="coredns", k8s_deployment_name="coredns", k8s_namespace_name="kube-system", k8s_node_name="k3d-kubernetes-mixin-otel-server-0", k8s_pod_name="coredns-576bfc4dc7-5xhx7", k8s_replicaset_name="coredns-576bfc4dc7", service_instance_id="kube-system.coredns-576bfc4dc7-5xhx7.coredns", service_name="coredns", service_namespace="kube-system", service_version="1.10.1"',

  // Network labels (without container-specific labels)
  nginxNetworkLabels: 'host_name="k3d-kubernetes-mixin-otel-server-0", instance="default.nginx-abc123-xyz.nginx", job="default/nginx", k8s_cluster_name="kubernetes-mixin-otel", k8s_namespace_name="default", k8s_node_name="k3d-kubernetes-mixin-otel-server-0", k8s_pod_name="nginx-abc123-xyz"',

  // Node labels
  nodeLabels: 'k8s_cluster_name="kubernetes-mixin-otel", k8s_node_name="k3d-kubernetes-mixin-otel-server-0"',

  // Input series generators
  cpuTimeSeries(labels, values):: {
    series: 'k8s_pod_cpu_time_seconds_total{%s}' % labels,
    values: values,
  },

  cpuRequestSeries(labels, values):: {
    series: 'k8s_container_cpu_request{%s}' % labels,
    values: values,
  },

  cpuLimitSeries(labels, values):: {
    series: 'k8s_container_cpu_limit{%s}' % labels,
    values: values,
  },

  memoryWSSeries(labels, values):: {
    series: 'k8s_pod_memory_working_set_bytes{%s}' % labels,
    values: values,
  },

  memoryRequestSeries(labels, values):: {
    series: 'k8s_container_memory_request_bytes{%s}' % labels,
    values: values,
  },

  memoryLimitSeries(labels, values):: {
    series: 'k8s_container_memory_limit_bytes{%s}' % labels,
    values: values,
  },

  memoryRSSSeries(labels, values):: {
    series: 'k8s_pod_memory_rss_bytes{%s}' % labels,
    values: values,
  },

  memoryUsageSeries(labels, values):: {
    series: 'k8s_pod_memory_usage_bytes{%s}' % labels,
    values: values,
  },

  nodeAllocatableCPUSeries(labels, values):: {
    series: 'k8s_node_allocatable_cpu_cores{%s}' % labels,
    values: values,
  },

  nodeAllocatableMemorySeries(labels, values):: {
    series: 'k8s_node_allocatable_memory_bytes{%s}' % labels,
    values: values,
  },

  networkIOSeries(labels, direction, values):: {
    series: 'k8s_pod_network_io_bytes_total{%s, direction="%s", interface="eth0"}' % [labels, direction],
    values: values,
  },

  networkErrorsSeries(labels, direction, values):: {
    series: 'k8s_pod_network_errors_total{%s, direction="%s", interface="eth0"}' % [labels, direction],
    values: values,
  },

  podPhaseSeries(labels, values):: {
    series: 'k8s_pod_phase{%s}' % labels,
    values: values,
  },
};

// ============================================================================
// CLUSTER DASHBOARD TESTS
// ============================================================================
local clusterCPUUsageTest = {
  name: 'Cluster: CPU Usage by Namespace',
  interval: '1m',
  input_series: [
    // nginx: 60 CPU seconds per minute = 1 core usage
    testData.cpuTimeSeries(testData.nginxLabels, '0+60x10'),
    // coredns: 30 CPU seconds per minute = 0.5 core usage
    testData.cpuTimeSeries(testData.corednsLabels, '0+30x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(cluster.cpuUsageByNamespace(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_namespace_name="default"}', value: 1 },
        { labels: '{k8s_namespace_name="kube-system"}', value: 0.5 },
      ],
    },
  ],
};

local clusterCPURequestsTest = {
  name: 'Cluster: CPU Requests by Namespace',
  interval: '1m',
  input_series: [
    testData.cpuRequestSeries(testData.nginxLabels, '0.5x10'),
    testData.cpuRequestSeries(testData.corednsLabels, '0.25x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(cluster.cpuRequestsByNamespace(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_namespace_name="default"}', value: 0.5 },
        { labels: '{k8s_namespace_name="kube-system"}', value: 0.25 },
      ],
    },
  ],
};

local clusterMemoryUsageTest = {
  name: 'Cluster: Memory Usage by Namespace',
  interval: '1m',
  input_series: [
    // nginx: 100MB
    testData.memoryWSSeries(testData.nginxLabels, '104857600x10'),
    // coredns: 50MB
    testData.memoryWSSeries(testData.corednsLabels, '52428800x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(cluster.memoryUsageByNamespace(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_namespace_name="default"}', value: 104857600 },
        { labels: '{k8s_namespace_name="kube-system"}', value: 52428800 },
      ],
    },
  ],
};

// ============================================================================
// NAMESPACE DASHBOARD TESTS
// ============================================================================
local namespaceCPUUsageTest = {
  name: 'Namespace: CPU Usage by Pod',
  interval: '1m',
  input_series: [
    testData.cpuTimeSeries(testData.nginxLabels, '0+60x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(namespace.cpuUsageByPod(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_pod_name="nginx-abc123-xyz"}', value: 1 },
      ],
    },
  ],
};

local namespaceMemoryUsageTest = {
  name: 'Namespace: Memory Usage by Pod',
  interval: '1m',
  input_series: [
    testData.memoryWSSeries(testData.nginxLabels, '104857600x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(namespace.memoryUsageByPod(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_pod_name="nginx-abc123-xyz"}', value: 104857600 },
      ],
    },
  ],
};

local namespaceCPURequestsTest = {
  name: 'Namespace: CPU Requests with Active Pod Filter',
  interval: '1m',
  input_series: [
    testData.cpuRequestSeries(testData.nginxLabels, '0.5x10'),
    // Pod phase 2 = Running
    testData.podPhaseSeries(testData.nginxLabels, '2x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(namespace.cpuRequestsByPod(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_pod_name="nginx-abc123-xyz"}', value: 0.5 },
      ],
    },
  ],
};

local namespaceNetworkReceiveTest = {
  name: 'Namespace: Network Receive Bandwidth',
  interval: '1m',
  input_series: [
    // 1MB per minute = ~17476 bytes/sec
    testData.networkIOSeries(testData.nginxNetworkLabels, 'receive', '0+1048576x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(namespace.networkReceiveBandwidth(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_namespace_name="default"}', value: 17476.266666666666 },
      ],
    },
  ],
};

// ============================================================================
// POD DASHBOARD TESTS
// ============================================================================
local podCPUUsageTest = {
  name: 'Pod: CPU Usage by Container',
  interval: '1m',
  input_series: [
    testData.cpuTimeSeries(testData.nginxLabels, '0+60x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(pod.cpuUsageByContainer(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_container_name="nginx"}', value: 1 },
      ],
    },
  ],
};

local podMemoryRequestsTest = {
  name: 'Pod: Memory Requests',
  interval: '1m',
  input_series: [
    // 128MB request
    testData.memoryRequestSeries(testData.nginxLabels, '134217728x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(pod.memoryRequests(config))),
      eval_time: '10m',
      exp_samples: [
        { labels: '{k8s_pod_name="nginx-abc123-xyz"}', value: 134217728 },
      ],
    },
  ],
};

local podMemoryCacheTest = {
  name: 'Pod: Memory Cache (usage - rss)',
  interval: '1m',
  input_series: [
    // Usage: 100MB
    testData.memoryUsageSeries(testData.nginxLabels, '104857600x10'),
    // RSS: 80MB
    testData.memoryRSSSeries(testData.nginxLabels, '83886080x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(pod.memoryUsageCache(config))),
      eval_time: '10m',
      exp_samples: [
        // Cache = 100MB - 80MB = 20MB = 20971520 bytes
        { labels: '{k8s_pod_name="nginx-abc123-xyz"}', value: 20971520 },
      ],
    },
  ],
};

local podCPUUsageVsRequestsTest = {
  name: 'Pod: CPU Usage vs Requests Ratio',
  interval: '1m',
  input_series: [
    // 1 core usage
    testData.cpuTimeSeries(testData.nginxLabels, '0+60x10'),
    // 0.5 core request
    testData.cpuRequestSeries(testData.nginxLabels, '0.5x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(pod.cpuUsageVsRequests(config))),
      eval_time: '10m',
      exp_samples: [
        // 1 / 0.5 = 2
        { labels: '{k8s_pod_name="nginx-abc123-xyz"}', value: 2 },
      ],
    },
  ],
};

local podMemoryUsageVsLimitsTest = {
  name: 'Pod: Memory Usage vs Limits Ratio',
  interval: '1m',
  input_series: [
    // 100MB usage
    testData.memoryUsageSeries(testData.nginxLabels, '104857600x10'),
    // 256MB limit
    testData.memoryLimitSeries(testData.nginxLabels, '268435456x10'),
  ],
  promql_expr_test: [
    {
      expr: replaceVars(normalizeQuery(pod.memoryUsageVsLimits(config))),
      eval_time: '10m',
      exp_samples: [
        // 100MB / 256MB = 0.390625
        { labels: '{k8s_pod_name="nginx-abc123-xyz"}', value: 0.390625 },
      ],
    },
  ],
};

// ============================================================================
// FINAL OUTPUT
// ============================================================================
{
  evaluation_interval: '1m',
  tests: [
    // Cluster tests
    clusterCPUUsageTest,
    clusterCPURequestsTest,
    clusterMemoryUsageTest,

    // Namespace tests
    namespaceCPUUsageTest,
    namespaceMemoryUsageTest,
    namespaceCPURequestsTest,
    namespaceNetworkReceiveTest,

    // Pod tests
    podCPUUsageTest,
    podMemoryRequestsTest,
    podMemoryCacheTest,
    podCPUUsageVsRequestsTest,
    podMemoryUsageVsLimitsTest,
  ],
}

