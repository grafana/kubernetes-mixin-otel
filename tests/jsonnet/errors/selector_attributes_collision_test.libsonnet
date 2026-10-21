local selectors = import '../../../lib/selectors.libsonnet';

selectors.selector(
  'k8s_pod_network_io_bytes_total',
  {},
  attributes=[{ label: 'direction', operator: '=', value: 'transmit' }],
  config={ custom: { attributes: [{ label: 'direction', operator: '=', value: 'receive' }] } }
)
