(import 'resources/cluster.libsonnet') {
  grafanaDashboards+:: (import 'resources/pod.libsonnet').grafanaDashboards,
}
