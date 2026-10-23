local common = import '../../../dashboards/resources/queries/common.libsonnet';

common.metricSum(
  'k8s_pod_cpu_time_seconds_total',
  {},
  by=['k8s_namespace_name'],
  config={ custom: { groupingAttributes: ['deployment.environment.name'] } }
)
