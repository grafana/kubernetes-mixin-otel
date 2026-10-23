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
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-otelkubenodenotready)

**Meaning.** The node has not reported `Ready` for more than 15 minutes, so it
cannot host new pods. This alert covers both `False` (the kubelet reports it is
unhealthy) and `Unknown` (the kubelet has stopped reporting at all, which
usually means the node is unreachable rather than unhealthy). Check the metric
value to tell them apart: `0` is False, `-1` is Unknown.

**Impact.** Workloads already on the node may be evicted and rescheduled
elsewhere. Cluster capacity is reduced until the node recovers.

**Diagnosis.**

```shell
kubectl get node $NODE -o yaml
```

The `status.conditions` entry for `Ready` carries the reason and message — API
timeouts, kubelet connectivity problems, or a kubelet that has stopped posting
status. `kubectl describe node $NODE` also shows recent events.

**Mitigation.** Resolve the underlying cause (restart the kubelet, repair
networking, or replace the instance). If the node will not return, delete it so
the control plane stops scheduling against it.

See also [Node Conditions](https://kubernetes.io/docs/concepts/architecture/nodes/#condition)
and [Node Problem Detector](https://github.com/kubernetes/node-problem-detector).

##### Alert Name: "OTelKubeNodeMemoryPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active MemoryPressure Condition. Available memory has fallen below the eviction threshold and the kubelet may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-otelkubenodememorypressure)

**Meaning.** Available memory on the node has fallen below the kubelet's
eviction threshold (`memory.available`, default `100Mi`).

**Impact.** The kubelet evicts pods to reclaim memory. Pods managed by a
Deployment or StatefulSet are recreated elsewhere; bare pods are not.

**Diagnosis.**

```shell
kubectl describe node $NODE
kubectl top pods --all-namespaces --sort-by=memory
```

Look for pods without memory limits, or requests set well below actual usage.

**Mitigation.** Evict or resize the largest consumers, set memory limits on
workloads that lack them, or add capacity to the node pool.

##### Alert Name: "OTelKubeNodeDiskPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active DiskPressure Condition. Available disk space or inodes have fallen below the eviction threshold; the kubelet will garbage collect images and may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-otelkubenodediskpressure)

**Meaning.** Free disk space or inodes have fallen below the kubelet's eviction
thresholds (`nodefs.available` 10%, `nodefs.inodesFree` 5%, `imagefs.available`
15% by default).

**Impact.** The kubelet reclaims node-level resources first — unused container
images and dead containers — and only evicts pods if that is not enough.

**Diagnosis.**

```shell
kubectl describe node $NODE
```

On the node itself, identify what is consuming the filesystem: container logs,
images, or emptyDir volumes.

**Mitigation.** Image and container garbage collection usually clears this
without intervention. If it recurs, cap container log size, move emptyDir
workloads to persistent volumes, or grow the disk.

##### Alert Name: "OTelKubeNodePIDPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active PIDPressure Condition. The number of processes on the node is approaching the limit and the kubelet may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-otelkubenodepidpressure)

**Meaning.** Available process IDs on the node have fallen below the kubelet's
eviction threshold. Unlike memory and disk, there is nothing for the kubelet to
reclaim at node level, so it evicts pods directly.

**Impact.** Pods are evicted. New processes on the node may fail to start.

**Diagnosis.**

```shell
kubectl describe node $NODE
```

On the node, find the workload creating processes faster than it reaps them —
typically a container missing an init process, leaving zombies behind.

**Mitigation.** Restart or fix the offending workload. Set `pod-max-pids` on
the kubelet, or a PID resource limit on the workload, to stop one pod
exhausting the node.

## Resource quotas

Quota alerts read `k8s.resource_quota.used` and `k8s.resource_quota.hard_limit`
from the [k8sclusterreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver).
Both are disabled by default — if these alerts never fire, check that the
receiver enables them. A namespace may hold several ResourceQuota objects
(commonly scoped by PriorityClass), and Kubernetes enforces all of them, so each
is alerted on separately via `k8s.resourcequota.name`. That attribute is a
resource attribute, which most backends do not promote to a label by default;
without it, two quotas covering the same resource collapse into one series and
the ratio becomes meaningless. The dev collector config promotes it onto
datapoints in the `transform/promote_resource_attributes` processor.

##### Alert Name: "OTelKubeQuotaAlmostFull"
+ *Message*: `Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-otelkubequotaalmostfull)

**Meaning.** Between 90% and 100% of a quota's hard limit is consumed. Nothing
is being rejected yet.

**Impact.** The namespace is approaching the point where new objects of this
resource type are refused.

**Diagnosis.**

```shell
kubectl describe resourcequota $RESOURCEQUOTA -n $NAMESPACE
```

The output lists every constrained resource with its used and hard values.

**Mitigation.** Raise the quota, or reclaim capacity by removing unused objects
in the namespace.

##### Alert Name: "OTelKubeQuotaFullyUsed"
+ *Message*: `Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-otelkubequotafullyused)

**Meaning.** The quota is exactly at its hard limit.

**Impact.** The API server rejects new objects of this resource type in the
namespace with `403 Forbidden`. Deployments cannot scale up and evicted pods
cannot be replaced. This is reported at `info` because a namespace sized to its
quota sits here indefinitely by design; treat it as a capacity signal, not an
incident, unless the namespace is expected to have headroom.

**Diagnosis.**

```shell
kubectl describe resourcequota $RESOURCEQUOTA -n $NAMESPACE
kubectl get events -n $NAMESPACE --field-selector reason=FailedCreate
```

**Mitigation.** Raise the quota or free capacity. If the namespace holds
several ResourceQuota objects, confirm which one is binding — the alert names
it in `k8s_resourcequota_name`.

##### Alert Name: "OTelKubeQuotaExceeded"
+ *Message*: `Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-otelkubequotaexceeded)

**Meaning.** Usage is above the hard limit. Admission control cannot push usage
over a quota, so this means the limit was lowered beneath existing usage, or
objects were created before the quota existed.

**Impact.** New objects are rejected, as with a full quota, but unlike that case
this state cannot arise from normal operation and will not resolve on its own —
which is why it escalates to `warning`.

**Diagnosis.**

```shell
kubectl describe resourcequota $RESOURCEQUOTA -n $NAMESPACE
```

Compare against the quota's recent changes to see whether the limit was reduced.

**Mitigation.** Either restore the previous limit or delete objects until usage
is back under it.
