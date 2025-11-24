.PHONY: dev
dev:
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

.PHONY: generate-dashboards
generate-dashboards:
	@./scripts/generate-dashboards.sh
