local common = import '../../dashboards/resources/queries/common.libsonnet';

common.selector(
  'k8s_pod_cpu_time_seconds_total',
  {},
  config={ customAttributes: [
    { label: 'env', operator: '=', value: 'prod' },
    { label: 'env', operator: '=', value: 'staging' },
  ] }
)
