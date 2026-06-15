.DEFAULT_GOAL := help

DOCKER_IMG := ghcr.io/actions/actions-runner:latest

# owner/repo → runner-owner--repo (double-hyphen is safely reversible)
cname = runner-$(subst /,--,$(1))
# owner/repo → ~/.github-runner/owner--repo/_work
cwork = $(HOME)/.github-runner/$(subst /,--,$(1))/_work

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | sort

.PHONY: help

## register    — Register & start a runner for a repo. Usage: make register REPO=owner/repo
register:
	@set -e; \
	if [ -z "$(REPO)" ]; then \
		echo "ERROR: Usage: make run REPO=owner/repo"; \
		exit 1; \
	fi; \
	LABELS_ARG=$${LABELS:-self-hosted}; \
	CNAME="$(call cname,$(REPO))"; \
	WORK="$(call cwork,$(REPO))"; \
	echo "Getting registration token for $(REPO)..."; \
	TOKEN=$$(gh api --method POST -H "Accept: application/vnd.github+json" \
		"/repos/$(REPO)/actions/runners/registration-token" \
		--jq '.token // empty'); \
	if [ -z "$$TOKEN" ]; then \
		echo "ERROR: Failed to get registration token. Check:"; \
		echo "      1. Repo exists: https://github.com/$(REPO)"; \
		echo "      2. gh is authenticated (gh auth status)"; \
		echo "      3. Token has repo scope"; \
		exit 1; \
	fi; \
	URL="https://github.com/$(REPO)"; \
	mkdir -p "$$WORK"; \
	echo "Starting container '$$CNAME'..."; \
	docker rm -f "$$CNAME" 2>/dev/null || true; \
	docker run -d \
		--name "$$CNAME" \
		--restart unless-stopped \
		-e URL="$$URL" \
		-e TOKEN="$$TOKEN" \
		-e NAME="$$CNAME" \
		-e LABELS="$$LABELS_ARG" \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "$$WORK:/home/runner/_work" \
		$(DOCKER_IMG) \
		bash -c 'if [ ! -f .runner ]; then ./config.sh --url "$$URL" --token "$$TOKEN" --name "$$NAME" --labels "$$LABELS" --unattended; fi && exec ./bin/runsvc.sh'
	@echo "Runner registered for $(REPO). Check: make logs REPO=$(REPO)"

.PHONY: register

## list        — Show all runners (REPO + STATUS)
list:
	@printf "%-50s %s\n" "REPO" "STATUS"; \
	printf "%-50s %s\n" "----" "------"; \
	docker ps -a -f name=runner- --format "{{.Names}} {{.Status}}" | \
	while read -r CNAME STATUS; do \
		REPO=$$(echo "$$CNAME" | sed 's/^runner-//;s/--/\//'); \
		printf "%-50s %s\n" "$$REPO" "$$STATUS"; \
	done

.PHONY: list

## start       — Start a stopped runner. Usage: make start REPO=owner/repo
start:
	@if [ -z "$(REPO)" ]; then \
		echo "ERROR: Usage: make start REPO=owner/repo"; \
		exit 1; \
	fi
	docker start "$(call cname,$(REPO))"

.PHONY: start

## stop        — Stop a runner. Usage: make stop REPO=owner/repo
stop:
	@if [ -z "$(REPO)" ]; then \
		echo "ERROR: Usage: make stop REPO=owner/repo"; \
		exit 1; \
	fi
	docker stop "$(call cname,$(REPO))"

.PHONY: stop

## start-all   — Start all stopped runners
start-all:
	@CONTAINERS=$$(docker ps -aq -f name=runner- -f status=exited); \
	if [ -n "$$CONTAINERS" ]; then \
		docker start $$CONTAINERS; \
	fi

.PHONY: start-all

## stop-all    — Stop all running runners
stop-all:
	@CONTAINERS=$$(docker ps -q -f name=runner-); \
	if [ -n "$$CONTAINERS" ]; then \
		docker stop $$CONTAINERS; \
	fi

.PHONY: stop-all

## logs        — Tail runner logs. Usage: make logs REPO=owner/repo
logs:
	@if [ -z "$(REPO)" ]; then \
		echo "ERROR: Usage: make logs REPO=owner/repo"; \
		exit 1; \
	fi
	docker logs -f "$(call cname,$(REPO))"

.PHONY: logs

## unregister  — Remove from GitHub & delete container. Usage: make unregister REPO=owner/repo
unregister:
	@set -e; \
	if [ -z "$(REPO)" ]; then \
		echo "ERROR: Usage: make unregister REPO=owner/repo"; \
		exit 1; \
	fi; \
	CNAME="$(call cname,$(REPO))"; \
	echo "Looking up runner '$$CNAME' in $(REPO)..."; \
	RUNNER_ID=$$(gh api -H "Accept: application/vnd.github+json" \
		"/repos/$(REPO)/actions/runners" \
		--jq '.runners[] | select(.name == "$(call cname,$(REPO))") | .id' 2>/dev/null); \
	if [ -n "$$RUNNER_ID" ]; then \
		echo "Deleting runner #$$RUNNER_ID..."; \
		gh api --method DELETE -H "Accept: application/vnd.github+json" \
			"/repos/$(REPO)/actions/runners/$$RUNNER_ID" > /dev/null || true; \
		echo "Runner removed from GitHub."; \
	else \
		echo "No runner named '$(call cname,$(REPO))' found on GitHub—skipping."; \
	fi; \
	docker rm -f "$$CNAME" 2>/dev/null || true; \
	echo "Container removed."

.PHONY: unregister

## uninstall   — Remove ALL runner containers (keeps ~/.github-runner/)
uninstall:
	@echo "Removing all runner containers..."; \
	CONTAINERS=$$(docker ps -aq -f name=runner-); \
	if [ -n "$$CONTAINERS" ]; then \
		docker stop $$CONTAINERS 2>/dev/null || true; \
		docker rm $$CONTAINERS 2>/dev/null || true; \
		echo "All runner containers removed."; \
	else \
		echo "No runner containers found."; \
	fi; \
	echo "Work dirs retained in ~/.github-runner/."

.PHONY: uninstall
