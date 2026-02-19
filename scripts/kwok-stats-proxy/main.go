// kwok-stats-proxy provides a /stats/summary endpoint for kubeletstatsreceiver
// by reading simulated resource usage from KWOK's Kubernetes API.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	stats "k8s.io/kubelet/pkg/apis/stats/v1alpha1"
)

type server struct {
	client *kubernetes.Clientset

	// Track cumulative CPU time per pod/container for proper counter behavior
	mu              sync.RWMutex
	startTime       time.Time
	podCPUTime      map[string]uint64 // pod UID -> cumulative CPU nanoseconds
	containerCPUTime map[string]uint64 // pod UID + container name -> cumulative CPU nanoseconds
}

func main() {
	client, err := getKubeClient()
	if err != nil {
		log.Fatalf("Failed to create Kubernetes client: %v", err)
	}

	s := &server{
		client:           client,
		startTime:        time.Now(),
		podCPUTime:       make(map[string]uint64),
		containerCPUTime: make(map[string]uint64),
	}

	// Handle requests for specific nodes: /nodes/{nodeName}/stats/summary
	// Also handle root /stats/summary for single-node mode
	http.HandleFunc("/", s.handleRequest)

	port := os.Getenv("PORT")
	if port == "" {
		port = "10250"
	}

	log.Printf("Starting kwok-stats-proxy on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func (s *server) handleRequest(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path

	// Parse node name from path: /nodes/{nodeName}/stats/summary or /stats/summary
	var nodeName string
	if strings.HasPrefix(path, "/nodes/") {
		parts := strings.Split(path, "/")
		if len(parts) >= 4 && parts[3] == "stats" {
			nodeName = parts[2]
		}
	} else if path == "/stats/summary" {
		// Default to first node or env var
		nodeName = os.Getenv("NODE_NAME")
	}

	if nodeName == "" && !strings.HasSuffix(path, "/stats/summary") {
		http.NotFound(w, r)
		return
	}

	summary, err := s.getStatsSummary(r.Context(), nodeName)
	if err != nil {
		log.Printf("Error getting stats summary: %v", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(summary)
}

func (s *server) getStatsSummary(ctx context.Context, nodeName string) (*stats.Summary, error) {
	now := metav1.Now()
	startTime := metav1.NewTime(s.startTime)

	// Get all pods, optionally filtered by node
	listOpts := metav1.ListOptions{}
	if nodeName != "" {
		listOpts.FieldSelector = fmt.Sprintf("spec.nodeName=%s", nodeName)
	}

	pods, err := s.client.CoreV1().Pods("").List(ctx, listOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to list pods: %w", err)
	}

	// If no nodeName specified but we have pods, use the first pod's node
	if nodeName == "" && len(pods.Items) > 0 {
		nodeName = pods.Items[0].Spec.NodeName
	}
	if nodeName == "" {
		nodeName = "kwok-node"
	}

	// Calculate elapsed time since start for cumulative counters
	elapsed := time.Since(s.startTime)

	// Calculate node totals
	var nodeCPUNanos uint64 = 0
	var nodeCPUTime uint64 = 0
	var nodeMemBytes uint64 = 0

	podStats := make([]stats.PodStats, 0, len(pods.Items))

	s.mu.Lock()
	defer s.mu.Unlock()

	for _, pod := range pods.Items {
		if pod.Status.Phase != corev1.PodRunning {
			continue
		}

		podUID := string(pod.UID)
		podCPUNanos, podMemBytes := getPodResourceUsage(&pod)
		
		// Calculate cumulative CPU time: usage (cores) * elapsed time (nanoseconds)
		// UsageNanoCores is in nanocores (1e-9 cores), elapsed is in nanoseconds
		// CPU time = cores * seconds = (nanocores / 1e9) * (nanoseconds / 1e9) * 1e9 nanoseconds
		// Simplified: nanocores * seconds
		podCumulativeCPU := uint64(float64(podCPUNanos) * elapsed.Seconds())
		s.podCPUTime[podUID] = podCumulativeCPU

		nodeCPUNanos += podCPUNanos
		nodeCPUTime += podCumulativeCPU
		nodeMemBytes += podMemBytes

		// Pod memory limit: sum of container limits (for AvailableBytes only when any limit set; match real kubelet)
		var podMemLimit uint64
		for _, c := range pod.Spec.Containers {
			if mem := c.Resources.Limits.Memory(); mem != nil {
				podMemLimit += uint64(mem.Value())
			}
		}

		containers := make([]stats.ContainerStats, 0, len(pod.Spec.Containers))
		for _, container := range pod.Spec.Containers {
			containerKey := podUID + "/" + container.Name
			containerCPU, containerMem := getContainerResourceUsage(&pod, container.Name)
			
			// Calculate cumulative CPU time for container
			containerCumulativeCPU := uint64(float64(containerCPU) * elapsed.Seconds())
			s.containerCPUTime[containerKey] = containerCumulativeCPU

			// Container memory: include AvailableBytes only when container has memory limit (match real kubelet)
			containerMemLimit := uint64(0)
			if mem := container.Resources.Limits.Memory(); mem != nil {
				containerMemLimit = uint64(mem.Value())
			}
			containerMemStats := makeMemoryStats(now, containerMem, containerMemLimit)

			rootfs := makeContainerFsStats(now)
			logs := makeContainerFsStats(now)
			containers = append(containers, stats.ContainerStats{
				Name:      container.Name,
				StartTime: startTime,
				CPU: &stats.CPUStats{
					Time:                 now,
					UsageNanoCores:       &containerCPU,
					UsageCoreNanoSeconds: &containerCumulativeCPU,
				},
				Memory:  containerMemStats,
				Rootfs:  rootfs,
				Logs:    logs,
			})
		}

		// Network stats so k8s_pod_network_io_bytes_total and k8s_pod_network_errors_total exist.
		podNetwork := makeNetworkStats(now)
		// Pod memory: include AvailableBytes only when pod has memory limit (sum of container limits; match real kubelet)
		podMemStats := makeMemoryStats(now, podMemBytes, podMemLimit)

		podStats = append(podStats, stats.PodStats{
			PodRef: stats.PodReference{
				Name:      pod.Name,
				Namespace: pod.Namespace,
				UID:       string(pod.UID),
			},
			StartTime:     startTime,
			Containers:    containers,
			CPU: &stats.CPUStats{
				Time:                 now,
				UsageNanoCores:       &podCPUNanos,
				UsageCoreNanoSeconds: &podCumulativeCPU,
			},
			Memory:          podMemStats,
			Network:         podNetwork,
			EphemeralStorage: makeContainerFsStats(now),
			ProcessStats:    makeProcessStats(now),
		})
	}

	// Node-level memory: include AvailableBytes, PageFaults, MajorPageFaults (match dev metrics)
	nodeMemLimit := uint64(8 * 1024 * 1024 * 1024) // 8Gi simulated node memory
	nodeMemStats := makeMemoryStats(now, nodeMemBytes, nodeMemLimit)

	// Node-level network, filesystem, runtime, and system containers (match real kubelet for series count).
	nodeNetwork := makeNetworkStats(now)
	nodeFs := makeNodeFsStats(now)
	nodeRuntime := makeRuntimeStats(now)
	systemContainers := makeSystemContainers(now, startTime)

	return &stats.Summary{
		Node: stats.NodeStats{
			NodeName:         nodeName,
			StartTime:        startTime,
			SystemContainers: systemContainers,
			CPU: &stats.CPUStats{
				Time:                 now,
				UsageNanoCores:       &nodeCPUNanos,
				UsageCoreNanoSeconds: &nodeCPUTime,
			},
			Memory:  nodeMemStats,
			Network: nodeNetwork,
			Fs:      nodeFs,
			Runtime: nodeRuntime,
		},
		Pods: podStats,
	}, nil
}

// makeMemoryStats returns MemoryStats with UsageBytes, WorkingSetBytes, RSSBytes,
// optionally AvailableBytes (only when memoryLimitBytes > 0, to match real kubelet),
// PageFaults, and MajorPageFaults so kubeletstatsreceiver emits
// *_memory_available_bytes, *_memory_page_faults_ratio, *_memory_major_page_faults_ratio (match dev).
func makeMemoryStats(now metav1.Time, usageBytes uint64, memoryLimitBytes uint64) *stats.MemoryStats {
	workingSet := usageBytes
	rss := usageBytes
	var available *uint64
	if memoryLimitBytes > 0 && memoryLimitBytes > usageBytes {
		av := memoryLimitBytes - usageBytes
		available = &av
	}
	// Cumulative page faults (small values so ratio metrics are non-zero)
	pageFaults := uint64(100)
	majorPageFaults := uint64(10)
	return &stats.MemoryStats{
		Time:            now,
		AvailableBytes:  available,
		UsageBytes:      &usageBytes,
		WorkingSetBytes: &workingSet,
		RSSBytes:         &rss,
		PageFaults:      &pageFaults,
		MajorPageFaults: &majorPageFaults,
	}
}

// makeNetworkStats returns placeholder network stats so kubeletstatsreceiver emits
// k8s_pod_network_io_bytes_total and k8s_pod_network_errors_total (match real kubelet).
func makeNetworkStats(now metav1.Time) *stats.NetworkStats {
	rxBytes := uint64(1024)
	rxErrors := uint64(0)
	txBytes := uint64(2048)
	txErrors := uint64(0)
	return &stats.NetworkStats{
		Time: now,
		InterfaceStats: stats.InterfaceStats{
			Name:     "eth0",
			RxBytes:  &rxBytes,
			RxErrors: &rxErrors,
			TxBytes:  &txBytes,
			TxErrors: &txErrors,
		},
		Interfaces: []stats.InterfaceStats{
			{
				Name:     "eth0",
				RxBytes:  &rxBytes,
				RxErrors: &rxErrors,
				TxBytes:  &txBytes,
				TxErrors: &txErrors,
			},
		},
	}
}

// makeContainerFsStats returns small FsStats for container rootfs/logs and pod ephemeral storage.
func makeContainerFsStats(now metav1.Time) *stats.FsStats {
	used := uint64(128 * 1024 * 1024) // 128Mi
	capacity := uint64(10 * 1024 * 1024 * 1024)
	available := capacity - used
	inodes := uint64(100000)
	inodesUsed := uint64(1000)
	inodesFree := inodes - inodesUsed
	return &stats.FsStats{
		Time:           now,
		AvailableBytes: &available,
		CapacityBytes:  &capacity,
		UsedBytes:      &used,
		Inodes:         &inodes,
		InodesUsed:     &inodesUsed,
		InodesFree:     &inodesFree,
	}
}

// makeSystemContainers returns node system containers (kubelet, runtime, misc, pods) so
// kubeletstatsreceiver emits system container metrics (match real kubelet).
func makeSystemContainers(now, startTime metav1.Time) []stats.ContainerStats {
	cpuNanos := uint64(10 * 1_000_000)   // 10m
	cpuTime := uint64(1000 * 1_000_000)  // 1s in nanos
	memBytes := uint64(64 * 1024 * 1024) // 64Mi
	memLimit := uint64(128 * 1024 * 1024) // 128Mi for available
	names := []string{stats.SystemContainerKubelet, stats.SystemContainerRuntime, stats.SystemContainerMisc, stats.SystemContainerPods}
	out := make([]stats.ContainerStats, 0, len(names))
	for _, name := range names {
		out = append(out, stats.ContainerStats{
			Name:      name,
			StartTime: startTime,
			CPU: &stats.CPUStats{
				Time:                 now,
				UsageNanoCores:       &cpuNanos,
				UsageCoreNanoSeconds: &cpuTime,
			},
			Memory: makeMemoryStats(now, memBytes, memLimit),
		})
	}
	return out
}

// makeNodeFsStats returns placeholder node filesystem stats (match real kubelet).
func makeNodeFsStats(now metav1.Time) *stats.FsStats {
	used := uint64(2 * 1024 * 1024 * 1024)   // 2Gi
	capacity := uint64(50 * 1024 * 1024 * 1024) // 50Gi
	available := capacity - used
	inodes := uint64(1000000)
	inodesUsed := uint64(10000)
	inodesFree := inodes - inodesUsed
	return &stats.FsStats{
		Time:           now,
		AvailableBytes: &available,
		CapacityBytes:  &capacity,
		UsedBytes:      &used,
		Inodes:         &inodes,
		InodesUsed:     &inodesUsed,
		InodesFree:     &inodesFree,
	}
}

// makeRuntimeStats returns node Runtime (ImageFs + ContainerFs) so receiver emits runtime fs metrics.
func makeRuntimeStats(now metav1.Time) *stats.RuntimeStats {
	return &stats.RuntimeStats{
		ImageFs:     makeContainerFsStats(now),
		ContainerFs: makeContainerFsStats(now),
	}
}

// makeProcessStats returns pod process count so receiver emits process_stats metrics.
func makeProcessStats(now metav1.Time) *stats.ProcessStats {
	count := uint64(5)
	return &stats.ProcessStats{
		ProcessCount: &count,
	}
}

// getPodResourceUsage reads simulated resource usage from pod annotations
// KWOK sets these via ClusterResourceUsage CRDs
func getPodResourceUsage(pod *corev1.Pod) (cpuNanos uint64, memBytes uint64) {
	// Try to get from annotations first (KWOK style)
	if cpu, ok := pod.Annotations["kwok.x-k8s.io/usage-cpu"]; ok {
		if q, err := resource.ParseQuantity(cpu); err == nil {
			cpuNanos = uint64(q.MilliValue()) * 1_000_000 // milli to nano
		}
	}
	if mem, ok := pod.Annotations["kwok.x-k8s.io/usage-memory"]; ok {
		if q, err := resource.ParseQuantity(mem); err == nil {
			memBytes = uint64(q.Value())
		}
	}

	// Fallback: use requests from spec (simulated usage = requested)
	if cpuNanos == 0 || memBytes == 0 {
		for _, container := range pod.Spec.Containers {
			if cpuNanos == 0 {
				if cpu := container.Resources.Requests.Cpu(); cpu != nil {
					cpuNanos += uint64(cpu.MilliValue()) * 1_000_000
				}
			}
			if memBytes == 0 {
				if mem := container.Resources.Requests.Memory(); mem != nil {
					memBytes += uint64(mem.Value())
				}
			}
		}
	}

	// Default values if still zero
	if cpuNanos == 0 {
		cpuNanos = 50_000_000 // 50m
	}
	if memBytes == 0 {
		memBytes = 128 * 1024 * 1024 // 128Mi
	}

	return cpuNanos, memBytes
}

// getContainerResourceUsage returns simulated usage for a specific container
func getContainerResourceUsage(pod *corev1.Pod, containerName string) (cpuNanos uint64, memBytes uint64) {
	// For now, divide pod usage equally among containers
	// Could be enhanced to read per-container annotations
	podCPU, podMem := getPodResourceUsage(pod)
	numContainers := uint64(len(pod.Spec.Containers))
	if numContainers == 0 {
		numContainers = 1
	}
	return podCPU / numContainers, podMem / numContainers
}

func getKubeClient() (*kubernetes.Clientset, error) {
	// Try in-cluster config first
	config, err := rest.InClusterConfig()
	if err != nil {
		// Fall back to kubeconfig
		kubeconfig := os.Getenv("KUBECONFIG")
		if kubeconfig == "" {
			home, _ := os.UserHomeDir()
			kubeconfig = filepath.Join(home, ".kube", "config")
		}
		config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
		if err != nil {
			return nil, fmt.Errorf("failed to build config: %w", err)
		}
	}

	// Skip TLS verification for KWOK clusters (certificates may not include all hostnames)
	config.TLSClientConfig.Insecure = true
	config.TLSClientConfig.CAData = nil
	config.TLSClientConfig.CAFile = ""

	return kubernetes.NewForConfig(config)
}
