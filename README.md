# GitHub Self-Hosted Runner — local Mac (Colima + Docker)

Run CI pipelines for your GitHub repos on your own Mac so MRs get
green/red status without paying for GitHub-hosted minutes.

## Prerequisites

- [Colima](https://github.com/abiosoft/colima) (`brew install colima`)
- Docker CLI (`brew install docker`)
- [gh](https://cli.github.com/) (`brew install gh`)
- `gh auth login` — must be authenticated with a token that has
  **`repo`** scope (or **`admin:org`** for org runners)

## Quick Start

```bash
# 1. Start Colima (if not already running)
colima start

# 2. Set up the runner
make setup
make run REPO=matthew-andrews/my-project

# 3. Done — runner picks up CI from that repo
make status
make logs
```

## Daily Use

```bash
make status                       # check container status
make stop                         # pause (taking laptop out)
make start                        # resume (jobs queue while gone)
make logs                         # tail runner logs
make unregister REPO=owner/repo   # remove runner from repo entirely
```

## How the example workflow works

This repo includes `.github/workflows/hello.yml` — a trivial workflow
that runs on the `self-hosted` label. When you push a commit:

1. GitHub schedules a workflow run
2. Your self-hosted runner picks it up
3. It prints "Hello from self-hosted runner!" and some system info
4. Green check appears on the commit page

This proves the runner is correctly registered and working for this repo.

### Cleaning up the example

Once you've verified the runner works, delete `.github/workflows/` to
avoid unnecessary runs, or change `on: push` to `on: workflow_dispatch`.

## How it works

`make run REPO=owner/repo`:

1. Calls `gh api` to get a short-lived registration token
2. Starts the official `ghcr.io/actions/actions-runner` Docker container
3. The container runs `config.sh --token <TOKEN>` to register
4. The `.credentials` file is persisted in `~/.github-runner/`
5. The runner listens for jobs from that repo

The runner identity survives container restarts (but not container
removal — use `make unregister` first if you need to destroy it).

| Trigger | What happens |
|---|---|
| Push to repo | GitHub schedules workflow → runner picks it up |
| Job runs | Fresh container → `actions/checkout` → your steps |
| Result | Green check / red cross on the commit |
| You're offline | Jobs queue — runner picks them up on `make start` |

## Unregister

```bash
make unregister REPO=owner/repo
# Looks up the runner by name on GitHub, deletes it, removes container
```

## Uninstall

```bash
make uninstall
# Container removed. Config stays in ~/.github-runner/ for re-use
```
