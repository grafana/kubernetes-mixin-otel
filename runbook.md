# Kubernetes OTel Alert Runbooks

Runbooks for the alerts in this mixin. These alerts are built on OpenTelemetry
receiver metrics rather than kube-state-metrics, so they are named with an
`OTel` prefix and are not interchangeable with the upstream
[kubernetes-mixin](https://github.com/kubernetes-sigs/kubernetes-mixin) alerts
of similar names.

Node condition alerts read `k8s.node.condition_<name>` from the
[k8sclusterreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver),
which emits one metric per entry in `node_conditions_to_report` (default
`[Ready]`). A condition absent from that list produces no metric at all, not a
zero — so if one of these alerts never fires, check the collector config first.
Values are `1` for True, `0` for False and `-1` for Unknown.

## Node conditions

##### Alert Name: "OTelKubeNodeNotReady"
+ *Message*: `{{ $labels.k8s_node_name }} has been unready for more than 15 minutes.`
+ *Severity*: warning
+ *Runbook*: [Link](https://runbooks.prometheus-operator.dev/runbooks/kubernetes/kubenodenotready/)

Fires when the Ready condition is False or Unknown. Unknown means the kubelet
has stopped reporting status, so the node may be unreachable rather than
unhealthy.

##### Alert Name: "OTelKubeNodeMemoryPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active MemoryPressure Condition. Available memory has fallen below the eviction threshold and the kubelet may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://runbooks.prometheus-operator.dev/runbooks/kubernetes/kubenodepressure/)

##### Alert Name: "OTelKubeNodeDiskPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active DiskPressure Condition. Available disk space or inodes have fallen below the eviction threshold; the kubelet will garbage collect images and may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://runbooks.prometheus-operator.dev/runbooks/kubernetes/kubenodepressure/)

##### Alert Name: "OTelKubeNodePIDPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active PIDPressure Condition. The number of processes on the node is approaching the limit and the kubelet may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://runbooks.prometheus-operator.dev/runbooks/kubernetes/kubenodepressure/)
