.DEFAULT_GOAL := help

CONFIG_DIR  := $(HOME)/.github-runner
RUNNER_NAME := ws-mattandre-githubrunner
DOCKER_IMG  := ghcr.io/actions/actions-runner:latest

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | sort

.PHONY: help

## setup       — Pull runner image & create config directory
setup:
	mkdir -p $(CONFIG_DIR)
	docker pull $(DOCKER_IMG)
	@echo "Ready. Now run 'make run REPO=owner/repo'."

.PHONY: setup

## run         — Register & start runner for a repo. Usage: make run REPO=owner/repo LABELS=self-hosted,mac
run:
	@set -e; \
	if [ -z "$(REPO)" ]; then \
		echo "ERROR: Usage: make run REPO=owner/repo [LABELS=self-hosted,mac]"; \
		exit 1; \
	fi; \
	LABELS_ARG=$${LABELS:-self-hosted}; \
	echo "Getting registration token for $(REPO)..."; \
	TOKEN=$$(gh api --method POST -H "Accept: application/vnd.github+json" \
		"/repos/$(REPO)/actions/runners/registration-token" \
		--jq '.token // empty'); \
	if [ -z "$$TOKEN" ]; then \
		echo "ERROR: Failed to get registration token. Check that:"; \
		echo "      1. The repo exists: https://github.com/$(REPO)"; \
		echo "      2. gh is authenticated (gh auth status)"; \
		echo "      3. Token has repo scope"; \
		exit 1; \
	fi; \
	echo "Starting runner container..."; \
	docker rm -f github-runner 2>/dev/null || true; \
	docker run -d \
		--name github-runner \
		--restart unless-stopped \
		-e RUNNER_REPO_URL="https://github.com/$(REPO)" \
		-e RUNNER_NAME="$(RUNNER_NAME)" \
		-e RUNNER_TOKEN="$$TOKEN" \
		-e RUNNER_LABELS="$$LABELS_ARG" \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CONFIG_DIR)/_work:/home/runner/_work \
		$(DOCKER_IMG)
	@echo "Runner registered for $(REPO). Check logs: make logs"

.PHONY: run

## start       — Start runner container if stopped
start:
	docker start github-runner

.PHONY: start

## stop        — Stop runner container (laptop mode)
stop:
	docker stop github-runner

.PHONY: stop

## restart     — Stop then start
restart: stop start

.PHONY: restart

## status      — Show runner container status
status:
	docker ps -f name=github-runner --format "{{.Names}}: {{.Status}}"

.PHONY: status

## logs        — Tail runner logs
logs:
	docker logs -f github-runner

.PHONY: logs

## unregister  — Remove runner from GitHub and delete container. Usage: make unregister REPO=owner/repo
unregister:
	@if [ -z "$(REPO)" ]; then \
		echo "ERROR: Usage: make unregister REPO=owner/repo"; \
		exit 1; \
	fi
	@echo "Looking up runner ID for $(RUNNER_NAME) in $(REPO)..."
	RUNNER_ID=$$(gh api -H "Accept: application/vnd.github+json" \
		"/repos/$(REPO)/actions/runners" \
		--jq '.runners[] | select(.name == "$(RUNNER_NAME)") | .id' 2>/dev/null); \
	if [ -n "$$RUNNER_ID" ]; then \
		echo "Removing runner #$$RUNNER_ID..."; \
		gh api --method DELETE -H "Accept: application/vnd.github+json" \
			"/repos/$(REPO)/actions/runners/$$RUNNER_ID" > /dev/null; \
	else \
		echo "No runner named $(RUNNER_NAME) found in $(REPO)."; \
	fi; \
	docker rm -f github-runner 2>/dev/null || true; \
	@echo "Runner removed."

.PHONY: unregister

## uninstall   — Stop & remove container (config kept in ~/.github-runner)
uninstall:
	docker stop github-runner 2>/dev/null || true
	docker rm github-runner 2>/dev/null || true
	@echo "Container removed. Config retained in $(CONFIG_DIR)."
