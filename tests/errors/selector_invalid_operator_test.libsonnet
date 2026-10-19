local selectors = import '../../lib/selectors.libsonnet';

selectors.selector(
  'k8s_pod_cpu_time_seconds_total',
  {},
  config={ custom: { attributes: [
    { label: 'env', operator: '==', value: 'prod' },
  ] } }
)
