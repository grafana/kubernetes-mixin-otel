local mixin = import '../mixin.libsonnet';

// Output Prometheus recording rules in the standard format
// Using -S flag with jsonnet for raw string output
std.manifestYamlDoc({
  groups: mixin.prometheusRules.groups,
})
