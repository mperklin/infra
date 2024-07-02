SHELL := /bin/bash

########################################################################################
# Environment Checks
########################################################################################

CHECK_ENV:=$(shell ./scripts/check-environment.sh)
ifneq ($(CHECK_ENV),)
$(error Check environment dependencies.)
endif


########################################################################################
# Targets
########################################################################################

help: ## Help message
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

helm: ## Install Helm 3 dependency
	@./scripts/install-helm.sh

helm-plugins: ## Install Helm plugins
	@helm plugin install https://github.com/databus23/helm-diff

repos: ## Add Helm repositories for dependencies
	@echo "=> Installing Helm repos"
	@helm repo add grafana https://grafana.github.io/helm-charts
	@helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update
	@echo

tools: install-prometheus install-loki install-metrics install-dashboard ## Intall/Update Prometheus/Grafana, Loki, Metrics Server, Kubernetes dashboard

pull: ## Git pull node-launcher repository
	@git clean -idf
	@git pull origin $(shell git rev-parse --abbrev-ref HEAD)

update-dependencies:
	@echo "=> Updating Helm chart dependencies"
	@helm dependencies update ./arkeo-stack
	@echo

update-trust-state: ## Updates statesync trusted height/hash and Midgard blockstore hashes from Nine Realms
	@./scripts/update-trust-state.sh

pods: ## Get Kubernetes pods
	@./scripts/pods.sh

pre-install: pull update-dependencies ## Pre deploy steps
	@./scripts/pre-install.sh

install: update-dependencies ## Deploy
	@./scripts/install.sh

update: pull update-dependencies ## Update a deployment to latest version
	@./scripts/update.sh

status: ## Display current status of your Arkeo stack
	@./scripts/status.sh

reset: ## Reset and resync a service from scratch on your deployment. This command can take a while to sync back to 100%.
	@./scripts/reset.sh

snapshot: ## Snapshot a volume for a specific service.
	@./scripts/snapshot.sh

restore-snapshot: ## Restore a volume for a specific service from a snapshot.
	@./scripts/restore-snapshot.sh

wait-ready: ## Wait for all pods to be in Ready state
	@./scripts/wait-ready.sh

destroy: ## Uninstall current deployment
	@./scripts/destroy.sh

export-state: ## Export chain state
	@./scripts/export-state.sh

shell: ## Open a shell for a selected service
	@./scripts/shell.sh

debug: ## Open a shell for mounting volume to debug
	@./scripts/debug.sh

recover-ninerealms:
	@./scripts/recover-ninerealms.sh

watch: ## Watch the pods in real time
	@./scripts/watch.sh

logs: ## Display logs for a selected service
	@./scripts/logs.sh

restart: ## Restart a selected service
	@./scripts/restart.sh

halt: ## Halt a selected service
	@./scripts/halt.sh

set-monitoring: ## Enable PagerDuty or Deadmans Snitch monitoring via Prometheus/Grafana re-deploy
	@./scripts/set-monitoring.sh

destroy-tools: destroy-prometheus destroy-loki destroy-dashboard ## Uninstall Prometheus/Grafana, Loki, Kubernetes dashboard

install-loki: repos ## Install/Update Loki logs management stack
	@./scripts/install-loki.sh

destroy-loki: ## Uninstall Loki logs management stack
	@./scripts/destroy-loki.sh

install-prometheus: repos ## Install/Update Prometheus/Grafana stack
	@./scripts/install-prometheus.sh

destroy-prometheus: ## Uninstall Prometheus/Grafana stack
	@./scripts/destroy-prometheus.sh

install-metrics: repos ## Install/Update Metrics Server
	@echo "=> Installing Metrics"
	@kubectl get svc -A | grep -q metrics-server || kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	@echo

destroy-metrics: ## Uninstall Metrics Server
	@echo "=> Deleting Metrics"
	@kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	@echo

install-dashboard: repos ## Install/Update Kubernetes dashboard
	@echo "=> Installing Kubernetes Dashboard"
	@helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard -n kube-system --wait -f ./kubernetes-dashboard/values.yaml
	@kubectl apply -f ./kubernetes-dashboard/dashboard-admin.yaml
	@echo

destroy-dashboard: ## Uninstall Kubernetes dashboard
	@echo "=> Deleting Kubernetes Dashboard"
	@helm delete kubernetes-dashboard -n kube-system
	@echo

grafana: ## Access Grafana UI through port-forward locally
	@echo User: admin
	@echo Password: thorchain
	@echo Open your browser at http://localhost:3000
	@kubectl -n prometheus-system port-forward service/prometheus-grafana 3000:80

prometheus: ## Access Prometheus UI through port-forward locally
	@echo Open your browser at http://localhost:9090
	@kubectl -n prometheus-system port-forward service/prometheus-kube-prometheus-prometheus 9090

alert-manager: ## Access Alert-Manager UI through port-forward locally
	@echo Open your browser at http://localhost:9093
	@kubectl -n prometheus-system port-forward service/prometheus-kube-prometheus-alertmanager 9093

dashboard: ## Access Kubernetes Dashboard UI through port-forward locally
	@echo Open your browser at http://localhost:8000
	@kubectl -n kube-system port-forward service/kubernetes-dashboard 8000:443

lint: ## Run linters (development)
	./scripts/lint.sh

.PHONY: help helm repo pull tools install-loki install-prometheus install-metrics install-dashboard export-state hard-fork destroy-tools destroy-loki destroy-prometheus destroy-metrics prometheus grafana dashboard alert-manager mnemonic update-dependencies reset restart pods deploy update destroy status shell watch logs set-node-keys set-ip-address set-version pause resume telegram-bot destroy-telegram-bot lint

.EXPORT_ALL_VARIABLES:
