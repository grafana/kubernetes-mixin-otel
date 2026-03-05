BIN_DIR ?= $(shell pwd)/tmp/bin

JSONNET_VENDOR=vendor
GRAFANA_DASHBOARD_LINTER_BIN=$(BIN_DIR)/dashboard-linter
JB_BIN=$(BIN_DIR)/jb
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETLINT_BIN=$(BIN_DIR)/jsonnet-lint
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
TOOLING=$(JB_BIN) $(JSONNETLINT_BIN) $(JSONNET_BIN) $(JSONNETFMT_BIN) $(GRAFANA_DASHBOARD_LINTER_BIN)
JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s
SRC_DIR ?=dashboards
OUT_DIR ?=dashboards_out

# Find all libsonnet files recursively in the dashboards directory
DASHBOARD_SOURCES = $(shell find $(SRC_DIR) -name '*.libsonnet')

.PHONY: dev
dev: generate lint
	@cd scripts && ./lgtm.sh && \
	echo '' && \
	echo '╔═══════════════════════════════════════════════════════════════╗' && \
	echo '║             🚀 Development Environment Ready! 🚀              ║' && \
	echo '║                                                               ║' && \
	echo '║   Run `make dev-port-forward`                                 ║' && \
	echo '║   Grafana will be available at http://localhost:3000          ║' && \
	echo '║                                                               ║' && \
	echo '║   Data will be available in a few minutes.                    ║' && \
	echo '║                                                               ║' && \
	echo '║   Dashboards will refresh every 10s, run `make generate`      ║' && \
	echo '║   and refresh your browser to see the changes.                ║' && \
	echo '║                                                               ║' && \
	echo '╚═══════════════════════════════════════════════════════════════╝'

.PHONY: dev-port-forward
dev-port-forward:
	kubectl --context k3d-kubernetes-mixin-otel wait --for=condition=Ready pods -l app=lgtm --timeout=300s
	kubectl --context k3d-kubernetes-mixin-otel port-forward service/lgtm 3000:3000 4317:4317 4318:4318 9090:9090

.PHONY: dev-down
dev-down:
	k3d cluster delete kubernetes-mixin-otel

ENABLE_BEYLA ?= false
.PHONY: kwok
kwok: generate
	@cd scripts && NODE_COUNT=$(NODE_COUNT) POD_COUNT=$(POD_COUNT) KWOK_DEFAULT_NAMESPACE_PODS=$(KWOK_DEFAULT_NAMESPACE_PODS) CLUSTER_NAME=$(CLUSTER_NAME) ENABLE_BEYLA=$(ENABLE_BEYLA) ./run-kwok-env.sh && \
	echo '' && \
	echo '╔════════════════════════════════════════════════════════╗' && \
	echo '║           🚀 KWOK Environment Ready! 🚀                ║' && \
	echo '╠════════════════════════════════════════════════════════╣' && \
	echo '║  Grafana:     http://localhost:3001                    ║' && \
	echo '║  Prometheus:  http://localhost:8889/metrics            ║' && \
	echo '╠════════════════════════════════════════════════════════╣' && \
	printf '║  Cluster:     %-40s ║\n' '$(CLUSTER_NAME)' && \
	printf '║  Nodes/Pods:  %-40s ║\n' '$(NODE_COUNT) nodes, $(POD_COUNT) pods' && \
	printf '║  Context:     %-40s ║\n' 'kwok-$(CLUSTER_NAME)' && \
	printf '║  Beyla:       %-40s ║\n' '$(ENABLE_BEYLA)' && \
	echo '╠════════════════════════════════════════════════════════╣' && \
	echo '║  Run `make kwok-down` to tear down                     ║' && \
	echo '╚════════════════════════════════════════════════════════╝'

.PHONY: kwok-down
kwok-down:
	@docker rm -f kwok-otel-collector kwok-stats-proxy kwok-beyla lgtm 2>/dev/null || true
	@for c in $$(docker ps -a -q --filter "name=kwok-hostmetrics" 2>/dev/null); do docker rm -f $$c 2>/dev/null || true; done
	@for c in $$(docker network inspect kwok-$(CLUSTER_NAME) --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null); do docker rm -f $$c 2>/dev/null || true; done
	@kwokctl delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true
	@echo "KWOK environment torn down"

.PHONY: kwok-stats-proxy-rm
kwok-stats-proxy-rm:
	@docker rm -f kwok-stats-proxy 2>/dev/null || true

.PHONY: kwok-beyla
kwok-beyla:
	@cd scripts && ./run-kwok-beyla.sh

.PHONY: kwok-beyla-rm
kwok-beyla-rm:
	@docker stop kwok-beyla --timeout 3 2>/dev/null || true
	@docker rm -f kwok-beyla 2>/dev/null || true

# Default scale: parity with dev (1 node, 10 pods, 11 containers from cluster-workloads only). Override for larger: make kwok NODE_COUNT=50 POD_COUNT=200
NODE_COUNT ?= 1
CLUSTER_NAME ?= queries-testing
KWOK_DEFAULT_NAMESPACE_PODS ?= 2

.PHONY: kwok-nodes
kwok-nodes:
	@cd scripts && CLUSTER_NAME=$(CLUSTER_NAME) ./scale-kwok-nodes.sh $(NODE_COUNT)

# POD_COUNT=0 uses only cluster-workloads for exact parity with dev
POD_COUNT ?= 0
.PHONY: kwok-pods
kwok-pods:
	@cd scripts && KWOK_DEFAULT_NAMESPACE_PODS=$(KWOK_DEFAULT_NAMESPACE_PODS) CLUSTER_NAME=$(CLUSTER_NAME) ./create-kwok-pods.sh $(POD_COUNT)

.PHONY: kwok-resource-usage
kwok-resource-usage:
	@cd scripts && CLUSTER_NAME=$(CLUSTER_NAME) ./apply-kwok-resource-usage.sh

.PHONY: kwok-annotate-nodes
kwok-annotate-nodes:
	@cd scripts && CLUSTER_NAME=$(CLUSTER_NAME) ./annotate-kwok-nodes.sh

.PHONY: kwok-cluster-workloads
kwok-cluster-workloads:
	@cd scripts && CLUSTER_NAME=$(CLUSTER_NAME) ./apply-kwok-cluster-workloads.sh

.PHONY: kwok-setup
kwok-setup:
	@$(MAKE) kwok-nodes NODE_COUNT=$(NODE_COUNT) CLUSTER_NAME=$(CLUSTER_NAME)
	@KWOK_DEFAULT_NAMESPACE_PODS=$(KWOK_DEFAULT_NAMESPACE_PODS) $(MAKE) kwok-pods POD_COUNT=$(POD_COUNT) CLUSTER_NAME=$(CLUSTER_NAME)
	@$(MAKE) kwok-resource-usage CLUSTER_NAME=$(CLUSTER_NAME)
	@$(MAKE) kwok-annotate-nodes CLUSTER_NAME=$(CLUSTER_NAME)
	@$(MAKE) kwok-cluster-workloads CLUSTER_NAME=$(CLUSTER_NAME)

.PHONY: clean-dashboards
clean-dashboards:
	rm -f $(OUT_DIR)/*.json*
	rm -f $(OUT_DIR)/.dashboards-generated

.PHONY: generate
generate: $(OUT_DIR)/.dashboards-generated

$(JSONNET_VENDOR): $(JB_BIN) jsonnetfile.json
	$(JB_BIN) install

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from scripts/tools.go
	@cd scripts && go list -e -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o $(BIN_DIR) %

.PHONY: fmt
fmt: jsonnet-fmt

.PHONY: jsonnet-fmt
jsonnet-fmt: $(JSONNETFMT_BIN)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

$(OUT_DIR)/.dashboards-generated: $(JSONNET_BIN) $(JSONNET_VENDOR) mixin.libsonnet lib/dashboards.jsonnet $(DASHBOARD_SOURCES)
	@mkdir -p $(OUT_DIR)
	@$(JSONNET_BIN) -J vendor -m $(OUT_DIR) lib/dashboards.jsonnet
	@touch $@

.PHONY: lint
lint: jsonnet-lint dashboards-lint

.PHONY: jsonnet-lint
jsonnet-lint: $(JSONNETLINT_BIN) $(JSONNET_VENDOR)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETLINT_BIN) -J vendor

$(OUT_DIR)/.lint: $(OUT_DIR)/.dashboards-generated
	@cp .lint $@

.PHONY: dashboards-lint
dashboards-lint: $(GRAFANA_DASHBOARD_LINTER_BIN) $(OUT_DIR)/.lint
	# Replace $$interval:$$resolution var with $$__rate_interval to make dashboard-linter happy.
	@sed -i -e 's/$$interval:$$resolution/$$__rate_interval/g' $(OUT_DIR)/*.json
	@find $(OUT_DIR) -name '*.json' -print0 | xargs -n 1 -0 $(GRAFANA_DASHBOARD_LINTER_BIN) lint --strict

.PHONY: test
test: test-jsonnet

.PHONY: test-jsonnet
test-jsonnet: $(JSONNET_BIN) $(JSONNET_VENDOR)
	@echo "Running jsonnet query tests..."
	@$(JSONNET_BIN) -J vendor tests/pod_queries_test.libsonnet
	@$(JSONNET_BIN) -J vendor tests/namespace_queries_test.libsonnet
	@echo "All tests passed!"
