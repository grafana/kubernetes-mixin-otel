local common = import '../../dashboards/resources/queries/common.libsonnet';

common.selector(
  'k8s_pod_phase',
  { k8s_namespace_name: '${namespace:pipe}' },
  config={ custom: { attributes: [{ label: 'k8s_namespace_name', operator: '=', value: 'prod' }] } }
)
