local k8sMixinConfig = import 'github.com/kubernetes-monitoring/kubernetes-mixin/config.libsonnet';

k8sMixinConfig {
  _config+:: {
    cpuThrottlingPercent: 25,
  },
}
