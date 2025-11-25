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
DASHBOARD_SOURCES = $(shell find $(SRC_DIR) -name '*.libsonnet' 2>/dev/null)

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
	echo '╚═══════════════════════════════════════════════════════════════╝'

.PHONY: dev-port-forward
dev-port-forward:
	kubectl --context k3d-kubernetes-mixin-otel wait --for=condition=Ready pods -l app=lgtm --timeout=300s
	kubectl --context k3d-kubernetes-mixin-otel port-forward service/lgtm 3000:3000 4317:4317 4318:4318 9090:9090

.PHONY: dev-down
dev-down:
	k3d cluster delete kubernetes-mixin-otel

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
