// kwok-hostmetrics-faker generates fake hostmetrics OTLP data for multiple KWOK
// nodes and sends it to an OTLP HTTP endpoint. This replaces running N real
// otel-collector containers (one per node) with a single lightweight process.
//
// Environment variables:
//   NODE_NAMES        - comma-separated list of node names (required)
//   GATEWAY_ENDPOINT  - OTLP HTTP endpoint (default: http://lgtm:4318)
//   CLUSTER_NAME      - k8s.cluster.name attribute (default: queries-testing)
//   NUM_CPUS          - number of simulated CPUs per node (default: 4)
//   INTERVAL          - send interval (default: 30s)
package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// OTLP JSON types (subset needed for metric export)
// ---------------------------------------------------------------------------

type exportMetricsRequest struct {
	ResourceMetrics []resourceMetrics `json:"resourceMetrics"`
}

type resourceMetrics struct {
	Resource     resource       `json:"resource"`
	ScopeMetrics []scopeMetrics `json:"scopeMetrics"`
}

type resource struct {
	Attributes []keyValue `json:"attributes"`
}

type scopeMetrics struct {
	Scope   scope    `json:"scope"`
	Metrics []metric `json:"metrics"`
}

type scope struct {
	Name string `json:"name"`
}

type metric struct {
	Name  string `json:"name"`
	Unit  string `json:"unit,omitempty"`
	Sum   *sum   `json:"sum,omitempty"`
	Gauge *gauge `json:"gauge,omitempty"`
}

type sum struct {
	DataPoints             []numberDataPoint `json:"dataPoints"`
	AggregationTemporality int               `json:"aggregationTemporality"` // 2 = cumulative
	IsMonotonic            bool              `json:"isMonotonic"`
}

type gauge struct {
	DataPoints []numberDataPoint `json:"dataPoints"`
}

type numberDataPoint struct {
	Attributes        []keyValue `json:"attributes,omitempty"`
	StartTimeUnixNano string     `json:"startTimeUnixNano,omitempty"`
	TimeUnixNano      string     `json:"timeUnixNano"`
	AsDouble          float64    `json:"asDouble"`
}

type keyValue struct {
	Key   string   `json:"key"`
	Value anyValue `json:"value"`
}

type anyValue struct {
	StringValue *string `json:"stringValue,omitempty"`
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func strAttr(key, val string) keyValue {
	return keyValue{Key: key, Value: anyValue{StringValue: &val}}
}

func nanos(t time.Time) string {
	return strconv.FormatInt(t.UnixNano(), 10)
}

// withAttrs returns a new slice: base + extra (never mutates base).
func withAttrs(base []keyValue, extra ...keyValue) []keyValue {
	out := make([]keyValue, 0, len(base)+len(extra))
	out = append(out, base...)
	out = append(out, extra...)
	return out
}

func gaugeMetric(name, unit string, points []numberDataPoint) metric {
	return metric{Name: name, Unit: unit, Gauge: &gauge{DataPoints: points}}
}

func cumulativeSum(name, unit string, monotonic bool, points []numberDataPoint) metric {
	return metric{Name: name, Unit: unit, Sum: &sum{
		DataPoints:             points,
		AggregationTemporality: 2,
		IsMonotonic:            monotonic,
	}}
}

func gaugePoint(attrs []keyValue, nowNano string, val float64) numberDataPoint {
	return numberDataPoint{Attributes: attrs, TimeUnixNano: nowNano, AsDouble: val}
}

func counterPoint(attrs []keyValue, startNano, nowNano string, val float64) numberDataPoint {
	return numberDataPoint{
		Attributes:        attrs,
		StartTimeUnixNano: startNano,
		TimeUnixNano:      nowNano,
		AsDouble:          val,
	}
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const otlpScopeName = "github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver"

func main() {
	nodeNames := strings.Split(os.Getenv("NODE_NAMES"), ",")
	if len(nodeNames) == 0 || nodeNames[0] == "" {
		log.Fatal("NODE_NAMES env var required (comma-separated)")
	}

	gateway := envOr("GATEWAY_ENDPOINT", "http://lgtm:4318")
	clusterName := envOr("CLUSTER_NAME", "queries-testing")

	numCPUs := 4
	if v := os.Getenv("NUM_CPUS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			numCPUs = n
		}
	}

	interval := 30 * time.Second
	if v := os.Getenv("INTERVAL"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			interval = d
		}
	}

	startTime := time.Now()
	endpoint := strings.TrimRight(gateway, "/") + "/v1/metrics"

	log.Printf("kwok-hostmetrics-faker: nodes=%d cpus=%d interval=%s endpoint=%s",
		len(nodeNames), numCPUs, interval, endpoint)

	// Send immediately, then on each tick.
	send(endpoint, nodeNames, clusterName, numCPUs, startTime)
	ticker := time.NewTicker(interval)
	for range ticker.C {
		send(endpoint, nodeNames, clusterName, numCPUs, startTime)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// ---------------------------------------------------------------------------
// Build & send
// ---------------------------------------------------------------------------

func send(endpoint string, nodes []string, cluster string, numCPUs int, start time.Time) {
	now := time.Now()
	elapsed := now.Sub(start).Seconds()

	req := exportMetricsRequest{
		ResourceMetrics: make([]resourceMetrics, 0, len(nodes)),
	}
	for _, node := range nodes {
		req.ResourceMetrics = append(req.ResourceMetrics,
			buildNodeMetrics(node, cluster, numCPUs, start, now, elapsed))
	}

	body, err := json.Marshal(req)
	if err != nil {
		log.Printf("marshal: %v", err)
		return
	}

	resp, err := http.Post(endpoint, "application/json", bytes.NewReader(body))
	if err != nil {
		log.Printf("post: %v", err)
		return
	}
	resp.Body.Close()

	if resp.StatusCode >= 300 {
		log.Printf("gateway HTTP %d", resp.StatusCode)
	} else {
		log.Printf("sent %d nodes (%d bytes)", len(nodes), len(body))
	}
}

func buildNodeMetrics(node, cluster string, numCPUs int, start, now time.Time, elapsed float64) resourceMetrics {
	// Resource attributes (match resourcedetection + resource/hostname processors).
	res := resource{
		Attributes: []keyValue{
			strAttr("k8s.node.name", node),
			strAttr("host.name", node),
			strAttr("os.type", "linux"),
		},
	}

	// Datapoint-level base attributes matching:
	//   transform/copy_node_name  -> k8s.node.name, host.name
	//   attributes/k8sclustername -> k8s.cluster.name
	base := []keyValue{
		strAttr("k8s.node.name", node),
		strAttr("host.name", node),
		strAttr("k8s.cluster.name", cluster),
	}

	sn := nanos(start)
	nn := nanos(now)

	var metrics []metric
	metrics = append(metrics, cpuMetrics(base, numCPUs, sn, nn, elapsed)...)
	metrics = append(metrics, loadMetrics(base, nn)...)
	metrics = append(metrics, memoryMetrics(base, nn)...)
	metrics = append(metrics, diskMetrics(base, sn, nn, elapsed)...)
	metrics = append(metrics, filesystemMetrics(base, nn)...)
	metrics = append(metrics, networkMetrics(base, sn, nn, elapsed)...)

	return resourceMetrics{
		Resource: res,
		ScopeMetrics: []scopeMetrics{{
			Scope:   scope{Name: otlpScopeName},
			Metrics: metrics,
		}},
	}
}

// ---------------------------------------------------------------------------
// CPU scraper metrics
// ---------------------------------------------------------------------------

var cpuStates = []string{"user", "system", "idle", "nice", "softirq", "steal", "wait", "interrupt"}

// cpuRate returns a realistic CPU time accumulation rate (seconds/second).
func cpuRate(state string) float64 {
	switch state {
	case "idle":
		return 0.85
	case "user":
		return 0.10
	case "system":
		return 0.04
	default:
		return 0.002
	}
}

func cpuMetrics(base []keyValue, numCPUs int, startNano, nowNano string, elapsed float64) []metric {
	var timeDP, utilDP []numberDataPoint
	for i := 0; i < numCPUs; i++ {
		cpu := strconv.Itoa(i)
		for _, state := range cpuStates {
			rate := cpuRate(state)
			attrs := withAttrs(base, strAttr("cpu", cpu), strAttr("state", state))
			timeDP = append(timeDP, counterPoint(attrs, startNano, nowNano, rate*elapsed))
			utilDP = append(utilDP, gaugePoint(
				withAttrs(base, strAttr("cpu", cpu), strAttr("state", state)), nowNano, rate))
		}
	}

	return []metric{
		cumulativeSum("system.cpu.time", "s", true, timeDP),
		gaugeMetric("system.cpu.utilization", "1", utilDP),
		gaugeMetric("system.cpu.logical.count", "{cpus}",
			[]numberDataPoint{gaugePoint(withAttrs(base), nowNano, float64(numCPUs))}),
	}
}

// ---------------------------------------------------------------------------
// Load scraper metrics
// ---------------------------------------------------------------------------

func loadMetrics(base []keyValue, nowNano string) []metric {
	return []metric{
		gaugeMetric("system.cpu.load_average.1m", "",
			[]numberDataPoint{gaugePoint(withAttrs(base), nowNano, 1.5)}),
		gaugeMetric("system.cpu.load_average.5m", "",
			[]numberDataPoint{gaugePoint(withAttrs(base), nowNano, 1.2)}),
		gaugeMetric("system.cpu.load_average.15m", "",
			[]numberDataPoint{gaugePoint(withAttrs(base), nowNano, 0.9)}),
	}
}

// ---------------------------------------------------------------------------
// Memory scraper metrics
// ---------------------------------------------------------------------------

var memStates = []string{"used", "free", "buffered", "cached", "inactive", "slab_reclaimable", "slab_unreclaimable"}

const totalMemBytes = 8 * 1024 * 1024 * 1024 // 8 GiB

var memUsage = map[string]float64{
	"used":               3.5 * 1024 * 1024 * 1024,
	"free":               2.0 * 1024 * 1024 * 1024,
	"buffered":           0.5 * 1024 * 1024 * 1024,
	"cached":             1.5 * 1024 * 1024 * 1024,
	"inactive":           0.3 * 1024 * 1024 * 1024,
	"slab_reclaimable":   0.15 * 1024 * 1024 * 1024,
	"slab_unreclaimable": 0.05 * 1024 * 1024 * 1024,
}

func memoryMetrics(base []keyValue, nowNano string) []metric {
	var usageDP, utilDP []numberDataPoint
	for _, state := range memStates {
		usageDP = append(usageDP,
			gaugePoint(withAttrs(base, strAttr("state", state)), nowNano, memUsage[state]))
		utilDP = append(utilDP,
			gaugePoint(withAttrs(base, strAttr("state", state)), nowNano, memUsage[state]/totalMemBytes))
	}
	return []metric{
		gaugeMetric("system.memory.usage", "By", usageDP),
		gaugeMetric("system.memory.utilization", "1", utilDP),
		gaugeMetric("system.memory.limit", "By",
			[]numberDataPoint{gaugePoint(withAttrs(base), nowNano, totalMemBytes)}),
	}
}

// ---------------------------------------------------------------------------
// Disk scraper metrics
// ---------------------------------------------------------------------------

func diskMetrics(base []keyValue, startNano, nowNano string, elapsed float64) []metric {
	dev := "sda"
	dirs := []string{"read", "write"}

	ioRate := map[string]float64{"read": 50e6, "write": 30e6}       // bytes/sec
	opsRate := map[string]float64{"read": 100, "write": 50}         // ops/sec
	opTimeRate := map[string]float64{"read": 0.01, "write": 0.02}   // sec/sec

	var ioDP, opsDP, opTimeDP []numberDataPoint
	for _, d := range dirs {
		ioDP = append(ioDP, counterPoint(
			withAttrs(base, strAttr("device", dev), strAttr("direction", d)),
			startNano, nowNano, ioRate[d]*elapsed))
		opsDP = append(opsDP, counterPoint(
			withAttrs(base, strAttr("device", dev), strAttr("direction", d)),
			startNano, nowNano, opsRate[d]*elapsed))
		opTimeDP = append(opTimeDP, counterPoint(
			withAttrs(base, strAttr("device", dev), strAttr("direction", d)),
			startNano, nowNano, opTimeRate[d]*elapsed))
	}

	ioTimeDP := []numberDataPoint{
		counterPoint(withAttrs(base, strAttr("device", dev)), startNano, nowNano, 0.03*elapsed),
	}
	pendingDP := []numberDataPoint{
		gaugePoint(withAttrs(base, strAttr("device", dev)), nowNano, 0),
	}

	return []metric{
		cumulativeSum("system.disk.io", "By", true, ioDP),
		cumulativeSum("system.disk.operations", "{operations}", true, opsDP),
		cumulativeSum("system.disk.io_time", "s", true, ioTimeDP),
		cumulativeSum("system.disk.operation_time", "s", true, opTimeDP),
		gaugeMetric("system.disk.pending_operations", "{operations}", pendingDP),
	}
}

// ---------------------------------------------------------------------------
// Filesystem scraper metrics
// ---------------------------------------------------------------------------

func filesystemMetrics(base []keyValue, nowNano string) []metric {
	dev, mp, fsType, mode := "/dev/sda1", "/", "ext4", "rw"
	capacity := 50.0 * 1024 * 1024 * 1024 // 50 GiB
	usage := map[string]float64{
		"used":     20e9,
		"free":     25e9,
		"reserved": 5e9,
	}

	fsBase := withAttrs(base,
		strAttr("device", dev),
		strAttr("mountpoint", mp),
		strAttr("type", fsType),
		strAttr("mode", mode),
	)

	states := []string{"used", "free", "reserved"}
	var usageDP []numberDataPoint
	for _, s := range states {
		usageDP = append(usageDP,
			gaugePoint(withAttrs(fsBase, strAttr("state", s)), nowNano, usage[s]))
	}

	utilDP := []numberDataPoint{
		gaugePoint(withAttrs(fsBase), nowNano, usage["used"]/capacity),
	}

	return []metric{
		gaugeMetric("system.filesystem.usage", "By", usageDP),
		gaugeMetric("system.filesystem.utilization", "1", utilDP),
	}
}

// ---------------------------------------------------------------------------
// Network scraper metrics
// ---------------------------------------------------------------------------

func networkMetrics(base []keyValue, startNano, nowNano string, elapsed float64) []metric {
	dev := "eth0"
	dirs := []string{"transmit", "receive"}

	ioRate := map[string]float64{"receive": 10e6, "transmit": 5e6}
	pktRate := map[string]float64{"receive": 1000, "transmit": 800}

	var ioDP, pktDP, errDP, dropDP []numberDataPoint
	for _, d := range dirs {
		attrs := withAttrs(base, strAttr("device", dev), strAttr("direction", d))
		ioDP = append(ioDP, counterPoint(attrs, startNano, nowNano, ioRate[d]*elapsed))
		pktDP = append(pktDP, counterPoint(
			withAttrs(base, strAttr("device", dev), strAttr("direction", d)),
			startNano, nowNano, pktRate[d]*elapsed))
		errDP = append(errDP, counterPoint(
			withAttrs(base, strAttr("device", dev), strAttr("direction", d)),
			startNano, nowNano, 0))
		dropDP = append(dropDP, counterPoint(
			withAttrs(base, strAttr("device", dev), strAttr("direction", d)),
			startNano, nowNano, 0))
	}

	// Connections: common TCP states.
	connStates := []string{"ESTABLISHED", "LISTEN", "TIME_WAIT"}
	var connDP []numberDataPoint
	for _, s := range connStates {
		connDP = append(connDP,
			gaugePoint(withAttrs(base, strAttr("protocol", "tcp"), strAttr("state", s)), nowNano, 10))
	}

	return []metric{
		cumulativeSum("system.network.io", "By", true, ioDP),
		cumulativeSum("system.network.packets", "{packets}", true, pktDP),
		cumulativeSum("system.network.errors", "{errors}", true, errDP),
		cumulativeSum("system.network.dropped", "{packets}", true, dropDP),
		gaugeMetric("system.network.connections", "{connections}", connDP),
	}
}
