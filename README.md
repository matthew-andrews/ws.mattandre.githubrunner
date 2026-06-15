# GitHub Self-Hosted Runner — local Mac (Colima + Docker)

Run CI pipelines for your GitHub repos on your own Mac so commits get
green/red status without paying for GitHub-hosted minutes.

Supports **multiple repos** — one container per repo, all managed
from a single Makefile.

## Prerequisites

- [Colima](https://github.com/abiosoft/colima) (`brew install colima`)
- Docker CLI (`brew install docker`)
- [gh](https://cli.github.com/) (`brew install gh`)
- `gh auth login` — must be authenticated with a token that has
  **`repo`** scope

## Quick Start

```bash
# 1. Start Colima (if not already running)
colima start

# 2. Set up the runner for a repo
make setup
make register REPO=matthew-andrews/my-project

# 3. Add another repo (different container, same Makefile)
make register REPO=matthew-andrews/another-project

# 4. See all runners
make list
```

## Targets

| Target | Usage | Description |
|---|---|---|
| `setup` | `make setup` | Pull the runner image |
| `register` | `make register REPO=owner/repo` | Register & start a runner for a repo |
| `list` | `make list` | Show all repos and their runner status |
| `logs` | `make logs REPO=owner/repo` | Tail logs for a specific runner |
| `start` | `make start REPO=owner/repo` | Start a stopped runner |
| `stop` | `make stop REPO=owner/repo` | Stop a runner (laptop mode) |
| `start-all` | `make start-all` | Start all stopped runners |
| `stop-all` | `make stop-all` | Stop all running runners |
| `unregister` | `make unregister REPO=owner/repo` | Remove from GitHub & delete container |
| `uninstall` | `make uninstall` | Remove ALL runner containers |

## Example workflow

This repo includes `.github/workflows/hello.yml` — a trivial workflow
that runs on `runs-on: self-hosted`. Push a commit and the runner
picks it up:

```
Hello from self-hosted runner!
```

## How it works

`make register REPO=owner/repo`:

1. Calls `gh api --method POST` to get a short-lived registration token
2. Starts `ghcr.io/actions/actions-runner` with an inline `config.sh`
   script that runs `./config.sh --url <URL> --token <TOKEN> --unattended`
3. On restart (`make start`), the `.runner` file persists in the
   container's writable layer, so config is skipped

Container naming: `runner-{owner}--{repo}` (double-hyphen so the
reverse `/` mapping is unambiguous). Work dirs go in
`~/.github-runner/{owner}--{repo}/_work`.

| Trigger | What happens |
|---|---|
| Push to any registered repo | GitHub schedules workflow → runner picks it up |
| Job runs | Container → `actions/checkout` → your steps |
| Result | Green check / red cross on the commit |
| You're offline | Jobs queue — runners catch up on `make start` / `make start-all` |

## Unregister a single repo

```bash
make unregister REPO=owner/repo
# Removes from GitHub + deletes container. Work dir kept in ~/.github-runner/
```

## Uninstall all

```bash
make uninstall
# Removes ALL runner containers. Work dirs kept in ~/.github-runner/
```

## Container name reference

| `REPO=` | Container name |
|---|---|
| `matthew-andrews/ws.mattandre.ai-box` | `runner-matthew-andrews--ai-box` |
| `matthew-andrews/ws.mattandre.githubrunner` | `runner-matthew-andrews--ws.mattandre.githubrunner` |
