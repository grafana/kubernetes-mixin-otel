local alerts = (import '../mixin.libsonnet').prometheusAlerts;

{
  'prometheus_alerts.yaml': std.manifestYamlDoc(alerts),
}
