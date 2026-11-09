# Kubernetes OTel Alert Runbooks

Runbooks for the alerts in this mixin. These alerts are built on OpenTelemetry
receiver metrics rather than kube-state-metrics, so they are named with a
`K8s` prefix and are not interchangeable with the upstream
[kubernetes-mixin](https://github.com/kubernetes-sigs/kubernetes-mixin) alerts
of similar names.

Node condition alerts read `k8s.node.condition_<name>` from the
[k8sclusterreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.153.0/receiver/k8sclusterreceiver),
which emits one metric per entry in `node_conditions_to_report` (default
`[Ready]`). A condition absent from that list produces no metric at all, not a
zero — so if one of these alerts never fires, check the collector config first.
Values are `1` for True, `0` for False and `-1` for Unknown.

## Node conditions

##### Alert Name: "K8sNodeNotReady"
+ *Message*: `{{ $labels.k8s_node_name }} has been unready for more than 15 minutes.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8snodenotready)

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

##### Alert Name: "K8sNodeMemoryPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active MemoryPressure Condition. Available memory has fallen below the eviction threshold and the kubelet may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8snodememorypressure)

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

##### Alert Name: "K8sNodeDiskPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active DiskPressure Condition. Available disk space or inodes have fallen below the eviction threshold; the kubelet will garbage collect images and may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8snodediskpressure)

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

##### Alert Name: "K8sNodePIDPressure"
+ *Message*: `{{ $labels.k8s_node_name }} has an active PIDPressure Condition. The number of processes on the node is approaching the limit and the kubelet may start evicting pods.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8snodepidpressure)

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

##### Alert Name: "K8sNodeEviction"
+ *Message*: `Node {{ $labels.k8s_node_name }} has evicted {{ $value }} pod(s) in the last 15 minutes.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8snodeeviction)

**Meaning.** Pods on the node newly report the status reason `Evicted`
(`k8s.pod.status_reason` of `1`, from the k8sclusterreceiver). The kubelet
evicts pods when a resource such as memory, disk or PIDs reaches an eviction
threshold. A pod can also be evicted when the scheduler preempts it to place a
pod with a higher priority class, for example a DaemonSet pod or one with a
node selector. The metric is disabled by default; if the alert never fires, enable
it.

**Impact.** The pod is terminated and its phase is set to `Failed`. A
Deployment or StatefulSet creates a replacement. The evicted Pod object stays
until it is deleted.

**Diagnosis.**

```shell
kubectl get pods -A --field-selector=spec.nodeName=$NODE,status.phase=Failed
kubectl describe pod $POD -n $NAMESPACE
kubectl describe node $NODE
```

The node's conditions show which pressure was active. See the pressure alerts
above.

**Mitigation.** Fix the pressure on the node. Set memory limits and requests on
workloads that lack them, or add capacity. Delete evicted pods once
investigated.

## Container resources

Overcommit alerts compare the CPU and memory requests of active pods against
`k8s.node.allocatable_cpu` and `k8s.node.allocatable_memory`. Those come from the
[k8sclusterreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.153.0/receiver/k8sclusterreceiver/metadata.yaml)
and are only emitted for the types listed in `allocatable_types_to_report`,
which defaults to `[]`; set it to `[cpu, memory]`.

##### Alert Name: "K8sCPUOvercommit"
+ *Message*: `Cluster {{ $labels.k8s_cluster_name }} has overcommitted CPU resource requests for Pods by {{ printf "%.2f" $value }} CPU cores beyond the capacity left if its largest node fails.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8scpuovercommit)

**Meaning.** Total CPU requests of Pending and Running pods exceed the
allocatable CPU of all nodes except the largest one. Clusters with a single node
never fire.

**Impact.** If the largest node fails, its pods cannot all be rescheduled and
some stay Pending.

**Diagnosis.**

```shell
kubectl describe nodes | grep -A 8 "Allocated resources"
kubectl get pods -A --field-selector=status.phase=Pending
```

**Mitigation.** Add nodes, or lower requests on over-provisioned workloads.

##### Alert Name: "K8sMemoryOvercommit"
+ *Message*: `Cluster {{ $labels.k8s_cluster_name }} has overcommitted memory resource requests for Pods by {{ $value | humanize }}B beyond the capacity left if its largest node fails.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8smemoryovercommit)

**Meaning.** Total memory requests of Pending and Running pods exceed the
allocatable memory of all nodes except the largest one. Clusters with a single
node never fire.

**Impact.** If the largest node fails, its pods cannot all be rescheduled and
some stay Pending.

**Diagnosis.**

```shell
kubectl describe nodes | grep -A 8 "Allocated resources"
kubectl get pods -A --field-selector=status.phase=Pending
```

**Mitigation.** Add nodes, or lower requests on over-provisioned workloads.

##### Alert Name: "K8sContainerMemoryNearLimit"
+ *Message*: `Container {{ $labels.k8s_container_name }} in pod {{ $labels.k8s_pod_name }} (namespace {{ $labels.k8s_namespace_name }}) is using {{ $value | humanizePercentage }} of its memory limit.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8scontainermemorynearlimit)

**Meaning.** A container's memory working set has stayed above
`containerMemoryNearLimitPercent` (default 90%) of its memory limit. It is
`container.memory.working_set` ([kubeletstatsreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.153.0/receiver/kubeletstatsreceiver/metadata.yaml))
divided by `k8s.container.memory_limit` ([k8sclusterreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.153.0/receiver/k8sclusterreceiver/metadata.yaml)),
both enabled by default. Containers without a limit are ignored.

**Impact.** The kernel may OOM-kill the container when it detects memory
pressure.

**Diagnosis.**

```shell
kubectl top pod $POD -n $NAMESPACE --containers
kubectl describe pod $POD -n $NAMESPACE
```

Look for `OOMKilled` under the container's last state.

**Mitigation.** Raise the memory limit, or fix the leak or unbounded cache in
the workload.

##### Alert Name: "K8sContainerOOMKilled"
+ *Message*: `Container {{ $labels.k8s_container_name }} in pod {{ $labels.k8s_pod_name }} (namespace {{ $labels.k8s_namespace_name }}) restarted after being OOM-killed in the last 15 minutes.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8scontaineroomkilled)

**Meaning.** A container's restart count (`k8s.container.restarts`) rose in the
last 15 minutes and its last termination reason is `OOMKilled`. The reason is
the `k8s.container.status.last_terminated_reason` attribute of the
k8sclusterreceiver, read from `target_info`. It is disabled by default; if the
alert never fires, enable it. A container with `restartPolicy: Never` is not
restarted, so it does not fire.

**Impact.** The kernel's OOM killer killed the container, either because it
exceeded its memory limit or because the node ran out of memory.

**Diagnosis.**

```shell
kubectl describe pod $POD -n $NAMESPACE
```

Look for `OOMKilled` and exit code `137` under the container's last state.

**Mitigation.** Raise the memory limit, or fix the leak or unbounded cache in
the workload. If the node ran out of memory, see `K8sNodeMemoryPressure`.

## Resource quotas

Quota alerts read `k8s.resource_quota.used` and `k8s.resource_quota.hard_limit`
from the [k8sclusterreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.153.0/receiver/k8sclusterreceiver/metadata.yaml).
Both are enabled by default — if these alerts never fire, check that the
namespace actually has a ResourceQuota object, since the metrics are only
emitted for quotas that exist. A namespace may hold several ResourceQuota objects
(commonly scoped by PriorityClass), and Kubernetes enforces all of them, so each
is alerted on separately via `k8s.resourcequota.name`. That attribute is a
resource attribute, which most backends do not promote to a label by default;
without it, two quotas covering the same resource collapse into one series and
the ratio becomes meaningless. The dev collector config promotes it onto
datapoints in the `transform/promote_resource_attributes` processor.

##### Alert Name: "K8sResourceQuotaAlmostFull"
+ *Message*: `Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8sresourcequotaalmostfull)

**Meaning.** A quota is between `resourceQuotaAlmostFullPercent` (default 90%)
and 100% consumed. Nothing is being rejected yet.

**Impact.** The namespace is approaching the point where new objects of this
resource type are refused.

**Diagnosis.**

```shell
kubectl describe resourcequota $RESOURCEQUOTA -n $NAMESPACE
```

The output lists every constrained resource with its used and hard values.

**Mitigation.** Raise the quota, or reclaim capacity by removing unused objects
in the namespace.

##### Alert Name: "K8sResourceQuotaFullyUsed"
+ *Message*: `Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8sresourcequotafullyused)

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

##### Alert Name: "K8sResourceQuotaExceeded"
+ *Message*: `Namespace {{ $labels.k8s_namespace_name }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota in ResourceQuota {{ $labels.k8s_resourcequota_name }}.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8sresourcequotaexceeded)

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

##### Alert Name: "K8sCPUQuotaOvercommit"
+ *Message*: `Cluster {{ $labels.k8s_cluster_name }} has CPU resource quota across namespaces at {{ printf "%.1f" $value }}x its allocatable CPU.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8scpuquotaovercommit)

**Meaning.** CPU request quotas (`cpu` or `requests.cpu`) across namespaces add
up to more than `resourceQuotaTotalOvercommitFactor` (default 1.5) times the cluster's
allocatable CPU. `limits.cpu` quotas are not counted.

**Impact.** Quota is checked at admission and does not set aside node capacity.
If namespaces use their quota, pods that don't fit stay Pending.

**Diagnosis.**

```shell
kubectl get resourcequota -A
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu
```

If the alert never fires, check that `k8s_node_allocatable_cpu` exists. The
k8sclusterreceiver only emits it for `allocatable_types_to_report`, which
defaults to empty.

**Mitigation.** Lower quotas, add nodes, or raise `resourceQuotaTotalOvercommitFactor`.

##### Alert Name: "K8sMemoryQuotaOvercommit"
+ *Message*: `Cluster {{ $labels.k8s_cluster_name }} has memory resource quota across namespaces at {{ printf "%.1f" $value }}x its allocatable memory.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8smemoryquotaovercommit)

**Meaning.** Memory request quotas (`memory` or `requests.memory`) across
namespaces add up to more than `resourceQuotaTotalOvercommitFactor` (default 1.5) times
the cluster's allocatable memory. `limits.memory` quotas are not counted.

**Impact.** Quota is checked at admission and does not set aside node capacity.
Pods that don't fit stay Pending, and memory cannot be throttled, so a full node
evicts pods or OOM-kills them.

**Diagnosis.**

```shell
kubectl get resourcequota -A
kubectl get nodes -o custom-columns=NAME:.metadata.name,MEMORY:.status.allocatable.memory
```

If the alert never fires, check that `k8s_node_allocatable_memory_bytes` exists.
The k8sclusterreceiver only emits it for `allocatable_types_to_report`, which
defaults to empty.

**Mitigation.** Lower quotas, add nodes, or raise `resourceQuotaTotalOvercommitFactor`.

##### Alert Name: "K8sResourceQuotaBlocksLargestPod"
+ *Message*: `ResourceQuota {{ $labels.k8s_resourcequota_name }} in namespace {{ $labels.k8s_namespace_name }} has less {{ $labels.resource }} headroom ({{ $value | humanize }}) than its largest pod needs, so another pod that size cannot be scheduled.`
+ *Severity*: info
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8sresourcequotablockslargestpod)

**Meaning.** The quota has headroom left, but less than the largest active pod
(Pending or Running) in the namespace requests. Another copy of that pod would be rejected.

**Impact.** The namespace is partially wedged: small workloads still schedule,
the largest ones no longer do. `K8sResourceQuotaAlmostFull` covers the same
window but cannot distinguish "near the limit and fine" from "near the limit and
unable to replace its biggest pod", which is what this alert adds.

For cpu and memory, headroom below the smallest pod is also below the largest, so
when `K8sResourceQuotaBlocksSmallestPod` fires, this alert will fire as well. This mixin
ships no inhibition; to be paged once, inhibit this alert on
`k8s_cluster_name, k8s_namespace_name, k8s_resourcequota_name, resource`:

```yaml
inhibit_rules:
  - source_matchers: [alertname = K8sResourceQuotaBlocksSmallestPod]
    target_matchers: [alertname = K8sResourceQuotaBlocksLargestPod]
    equal: [k8s_cluster_name, k8s_namespace_name, k8s_resourcequota_name, resource]
```

**Diagnosis.**

```shell
kubectl describe resourcequota $RESOURCEQUOTA -n $NAMESPACE
kubectl get pods -n $NAMESPACE -o custom-columns=NAME:.metadata.name,CPU:'.spec.containers[*].resources.requests.cpu',MEM:'.spec.containers[*].resources.requests.memory'
```

Compare the quota's remaining headroom against the largest pod listed.

**Mitigation.** Raise the quota, shrink the largest workload's requests, or
reclaim capacity from pods that no longer need it.

##### Alert Name: "K8sResourceQuotaBlocksSmallestPod"
+ *Message*: `ResourceQuota {{ $labels.k8s_resourcequota_name }} in namespace {{ $labels.k8s_namespace_name }} has less {{ $labels.resource }} headroom ({{ $value | humanize }}) than its smallest pod needs, so no further pod can be scheduled.`
+ *Severity*: warning
+ *Runbook*: [Link](https://github.com/grafana/kubernetes-mixin-otel/blob/main/runbook.md#alert-name-k8sresourcequotablockssmallestpod)

**Meaning.** Headroom is below even the smallest active pod (Pending or Running)
in the namespace, so nothing further can be admitted. For a `pods` count quota
this is simply zero slots remaining.

**Impact.** The namespace is fully wedged for this resource: no workload can
scale up and no evicted pod can be replaced. For cpu and memory resources
`K8sResourceQuotaBlocksLargestPod` fires alongside this one, since the smallest
pod not fitting implies the largest does not either; for `pods` it does not,
because a count quota has no largest-versus-smallest distinction and the branch
is emitted only here.

**Diagnosis.** As for `K8sResourceQuotaBlocksLargestPod`, plus:

```shell
kubectl get events -n $NAMESPACE --field-selector reason=FailedCreate
```

A quota rejection never produces a Pod object — the ReplicaSet controller fails
and nothing enters `Pending` — so these events, not pod status, are where the
rejection shows up.

**Mitigation.** Raise the quota or free capacity. Unlike the largest-pod case
there is no workload small enough to fit, so shrinking a single deployment's
requests may not be enough.

**Known limitations.** Both pod-fit alerts estimate the next pod's size from the
pods currently running, which carries three caveats:

+ Init containers and native sidecars are absent from
  `k8s.container.*_request`, so pods whose effective request is driven by an
  init container are under-counted and the alert may fire late.
+ ResourceQuota `scopeSelector` is not modelled. A quota scoped to a
  PriorityClass charges only a subset of the namespace's pods, but the pod size
  is computed namespace-wide, so the threshold may come from a pod the quota
  never charges.
+ A namespace with a quota but no active pods produces no alert, since there is
  no pod size to compare against.
