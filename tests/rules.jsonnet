local mixin = (import '../mixin.libsonnet') {
  _config+:: {
    k8sclusterreceiverSelector: 'job="monitoring/otel-collector"',
  },
};

std.manifestYamlDoc(mixin.prometheusRules)
