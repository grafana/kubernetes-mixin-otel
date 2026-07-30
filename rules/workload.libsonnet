{
  prometheusRules+:: {
    groups+: [
      {
        name: 'k8s.rules.pod.phase',
        rules: [
          {
            // OTel equivalent of namespace_workload_pod:kube_pod_owner:relabel.
            // Synthesizes `workload` and `workload_type` labels from OTel resource attributes
            // using a chained label_replace precedence: ReplicaSet → Job → DaemonSet →
            // StatefulSet → CronJob → Deployment (later entries overwrite earlier ones).
            // This means Deployment wins over ReplicaSet for Deployment-owned pods, and
            // CronJob wins over Job — matching the semantics of kube_pod_owner + kube_replicaset_owner
            // joins in the Prometheus equivalent.
            // Note: workload_type values are PascalCase ("DaemonSet" not "daemonset") because
            // OTel resource attributes use PascalCase. This differs from the KSM rule when
            // usePascalCaseForWorkloadTypeLabelValues=false.
            record: 'cluster_namespace_workload_pod_node:k8s_pod_phase:relabel',
            expr: |||
              label_replace(label_replace(
                label_replace(label_replace(
                  label_replace(label_replace(
                    label_replace(label_replace(
                      label_replace(label_replace(
                        label_replace(label_replace(
                          label_join(label_join(label_join(label_join(
                            max by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, k8s_node_name,
                                    k8s_cronjob_name, k8s_daemonset_name, k8s_deployment_name,
                                    k8s_job_name, k8s_replicaset_name, k8s_statefulset_name) (
                              k8s_pod_phase{%(k8sclusterreceiverSelector)s, k8s_pod_name!=""}
                            ),
                            "%(clusterLabel)s", ",", "k8s_cluster_name"),
                            "%(namespaceLabel)s", ",", "k8s_namespace_name"),
                            "%(podLabel)s", ",", "k8s_pod_name"),
                            "%(nodeLabel)s", ",", "k8s_node_name"),
                          "%(workloadLabel)s", "$1", "k8s_replicaset_name", "(.+)"),
                          "%(workloadTypeLabel)s", "ReplicaSet", "k8s_replicaset_name", ".+"),
                        "%(workloadLabel)s", "$1", "k8s_job_name", "(.+)"),
                        "%(workloadTypeLabel)s", "Job", "k8s_job_name", ".+"),
                      "%(workloadLabel)s", "$1", "k8s_daemonset_name", "(.+)"),
                      "%(workloadTypeLabel)s", "DaemonSet", "k8s_daemonset_name", ".+"),
                    "%(workloadLabel)s", "$1", "k8s_statefulset_name", "(.+)"),
                    "%(workloadTypeLabel)s", "StatefulSet", "k8s_statefulset_name", ".+"),
                  "%(workloadLabel)s", "$1", "k8s_cronjob_name", "(.+)"),
                  "%(workloadTypeLabel)s", "CronJob", "k8s_cronjob_name", ".+"),
                "%(workloadLabel)s", "$1", "k8s_deployment_name", "(.+)"),
                "%(workloadTypeLabel)s", "Deployment", "k8s_deployment_name", ".+")
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
