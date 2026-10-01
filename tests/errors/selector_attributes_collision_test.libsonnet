local common = import '../../dashboards/resources/queries/common.libsonnet';

common.selector(
  'k8s_pod_network_io_bytes_total',
  {},
  attributes=[{ label: 'direction', operator: '=', value: 'transmit' }],
  config={ custom: { attributes: [{ label: 'direction', operator: '=', value: 'receive' }] } }
)
