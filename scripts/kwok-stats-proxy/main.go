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
}

func main() {
	client, err := getKubeClient()
	if err != nil {
		log.Fatalf("Failed to create Kubernetes client: %v", err)
	}

	s := &server{client: client}

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
	startTime := metav1.NewTime(time.Now().Add(-24 * time.Hour))

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

	// Calculate node totals
	var nodeCPUNanos uint64 = 0
	var nodeMemBytes uint64 = 0

	podStats := make([]stats.PodStats, 0, len(pods.Items))

	for _, pod := range pods.Items {
		if pod.Status.Phase != corev1.PodRunning {
			continue
		}

		podCPUNanos, podMemBytes := getPodResourceUsage(&pod)
		nodeCPUNanos += podCPUNanos
		nodeMemBytes += podMemBytes

		containers := make([]stats.ContainerStats, 0, len(pod.Spec.Containers))
		for _, container := range pod.Spec.Containers {
			containerCPU, containerMem := getContainerResourceUsage(&pod, container.Name)

			containers = append(containers, stats.ContainerStats{
				Name:      container.Name,
				StartTime: startTime,
				CPU: &stats.CPUStats{
					Time:                 now,
					UsageNanoCores:       &containerCPU,
					UsageCoreNanoSeconds: func() *uint64 { v := containerCPU * 1000; return &v }(),
				},
				Memory: &stats.MemoryStats{
					Time:            now,
					UsageBytes:      &containerMem,
					WorkingSetBytes: &containerMem,
					RSSBytes:        &containerMem,
				},
			})
		}

		podStats = append(podStats, stats.PodStats{
			PodRef: stats.PodReference{
				Name:      pod.Name,
				Namespace: pod.Namespace,
				UID:       string(pod.UID),
			},
			StartTime:  startTime,
			Containers: containers,
			CPU: &stats.CPUStats{
				Time:           now,
				UsageNanoCores: &podCPUNanos,
			},
			Memory: &stats.MemoryStats{
				Time:            now,
				UsageBytes:      &podMemBytes,
				WorkingSetBytes: &podMemBytes,
			},
		})
	}

	return &stats.Summary{
		Node: stats.NodeStats{
			NodeName:  nodeName,
			StartTime: startTime,
			CPU: &stats.CPUStats{
				Time:           now,
				UsageNanoCores: &nodeCPUNanos,
			},
			Memory: &stats.MemoryStats{
				Time:            now,
				UsageBytes:      &nodeMemBytes,
				WorkingSetBytes: &nodeMemBytes,
			},
		},
		Pods: podStats,
	}, nil
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
