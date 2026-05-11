# Agent Harness — Operator Manual

A Docker-based runner that drives `claude` against a GitHub issue tracker using your **Claude subscription** (not an API key). One terminal, one issue at a time, four phases: plan → implement → review → merge.

**Design rationale:** [PRD #27](https://github.com/PaynePew/qr_code_generator/issues/27) · [ADR 0008](../docs/adr/0008-generic-agent-harness.md)

---

## Prerequisites

| Requirement | Check |
|---|---|
| Docker Desktop running | `docker info` |
| `gh` CLI logged in | `gh auth status` |
| `claude` CLI installed | `claude --version` |
| OAuth token obtained | `claude setup-token` |

**Getting the OAuth token:**

```powershell
# One-time setup:
claude setup-token
# Copy the printed token, then either:
$env:CLAUDE_CODE_OAUTH_TOKEN = '<token>'
# or drop it into .harness/.env.local (gitignored):
# CLAUDE_CODE_OAUTH_TOKEN=<token>
```

The token is a long-lived value from your Claude subscription account. It reaches the container via environment variable — never embedded in a `docker run` argument — so it does not appear in the host process listing.

---

## First run

```powershell
# Windows / PowerShell
pwsh ./.harness/run.ps1 -SmokeTest
```

```bash
# Linux / macOS / CI
./.harness/run.sh --smoke-test
```

A successful smoke test prints `PONG` from inside the container, confirming that Docker, the OAuth token, `gh` auth, and the image are all wired correctly. The smoke test costs no agent tokens.

If the image does not exist yet, the runner builds it automatically from `Dockerfile` and caches the hash in `.harness/.image-hash`. Subsequent runs skip the build unless `Dockerfile` changes.

---

## Four-phase pipeline

```
host (Windows / *nix)
│
│  ┌────────────────────────────────────────────────────────┐
│  │  run.ps1 / run.sh (bare)                               │
│  │                                                         │
│  │  ① PLAN      ─── claude run ──▶ ranked issue list      │
│  │                                  "Run #N? [Y/n]"        │
│  └────────────────────────────────────────────────────────┘
│
│  ┌────────────────────────────────────────────────────────┐
│  │  run.ps1 -Issue N                                      │
│  │                                                         │
│  │  ② IMPLEMENT ─── claude run ──▶ claims branch          │
│  │                                  writes code + tests    │
│  │                                  commits                │
│  │                                                         │
│  │  ③ REVIEW    ─── claude run ──▶ reads diff             │
│  │                                  refactors              │
│  │                                  commits refactor:      │
│  │                                                         │
│  │  ④ MERGE     ─── claude run ──▶ git push -u origin     │
│  │                                  gh pr create --fill    │
│  └────────────────────────────────────────────────────────┘
│
│  branch ready for human review on GitHub
```

Each phase runs in a fresh container with the repo bind-mounted as `/workspace`. Phases share state through git commits on the feature branch — no daemon, no shared queue, no `.harness/state.json`.

---

## Bare `run` flow

```powershell
pwsh ./.harness/run.ps1
```

1. Runs the **plan phase**: scans open issues, deconflicts against branches already claimed (`{branch_prefix}{N}-*`) and open PRs, ranks the remainder.
2. Prints the top candidate and alternatives.
3. Prompts: `Run #N? [Y/n]`
4. On confirmation, runs **implement → review → merge** on that issue.

```bash
# Linux / macOS equivalent (plan + implement only; review/merge PS-only in v1)
./.harness/run.sh
```

---

## Flag reference

### PowerShell (`run.ps1`)

| Flag | Description |
|---|---|
| *(bare)* | Plan → confirm → implement → review → merge |
| `-Plan` | Plan phase only; print ranking, exit. No implement. |
| `-Yes` | Plan + auto-confirm top candidate + full pipeline. No Y/n prompt. |
| `-Issue N` | Skip plan. Claim + implement + review + merge issue N. |
| `-Resume` | Resume implement on an existing branch for `-Issue N`. Fails if no matching branch exists. |
| `-SkipReview` | Skip the review phase after implement. Branch is ready to push manually. |
| `-SkipMerge` | Skip the merge phase after review. No push, no PR created. |
| `-SmokeTest` | Run the smoke-test prompt only (validates plumbing). |
| `-PlanModel <id>` | Override `agents.plan.model` from config. |
| `-ImplementModel <id>` | Override `agents.implement.model` from config. |
| `-ReviewModel <id>` | Override `agents.review.model` from config. |
| `-MergeModel <id>` | Override `agents.merge.model` from config. |
| `-PlanMaxTurns N` | Override `agents.plan.max_turns` from config. |
| `-ImplementMaxTurns N` | Override `agents.implement.max_turns` from config. |
| `-ReviewMaxTurns N` | Override `agents.review.max_turns` from config. |
| `-MergeMaxTurns N` | Override `agents.merge.max_turns` from config. |

### Bash (`run.sh`)

| Flag | Description |
|---|---|
| *(bare)* | Plan → confirm → implement |
| `--plan` | Plan phase only, print ranking, exit. |
| `--yes` | Plan + auto-confirm top candidate + implement. |
| `--issue N` | Skip plan, implement issue N. |
| `--smoke-test` | Validate plumbing only. |

---

## Manual issue selection from another terminal

If you want to run a specific issue without going through the plan phase:

```powershell
# Terminal A — already running plan on something else
# Terminal B — claim and implement a specific issue directly
pwsh ./.harness/run.ps1 -Issue 42
```

The plan phase deconflicts against local branches and open PRs, so a second terminal that runs plan will never pick an issue another terminal has claimed. If you skip plan (`-Issue N` directly), the branch-claim is still atomic: `git checkout -b` fails fast if the branch already exists.

---

## Resume after rate-limit

When `claude` exits non-zero with `Rate limit exceeded` or `usage_limit_exceeded` in the log, the wrapper surfaces the exact resume command:

```
Run interrupted. Resume with:
  pwsh ./.harness/run.ps1 -Issue 30 -Resume
```

Partial commits on the branch are preserved. `-Resume` skips branch creation and continues from the last committed state.

```powershell
pwsh ./.harness/run.ps1 -Issue 30 -Resume
```

---

## Config

`.harness/config.yml` is loaded once per run. Required keys:

```yaml
image:          agent-harness:latest
branch_prefix:  kanban-issue
tracker:
  type:         github
  repo:         PaynePew/qr_code_generator
```

Optional:

```yaml
defaults:
  model:        claude-sonnet-4-6

agents:
  plan:
    model:      claude-opus-4-7
    max_turns:  10
  implement:
    model:      claude-sonnet-4-6
    max_turns:  80
  review:
    model:      claude-opus-4-7
    max_turns:  30
  merge:
    model:      claude-sonnet-4-6
    max_turns:  20

docs:
  context:      CONTEXT.md
  prd_dir:      docs/prd
  adr_dir:      docs/adr

tests:
  block:        pytest backend/ && npm test --prefix frontend

typecheck:
  block:        npm run typecheck --prefix frontend

commit:
  style:        "Conventional Commits (feat/fix/test/docs/chore/refactor)"
```

CLI model flags (e.g. `-ImplementModel`) override config values for that run only.

---

## Troubleshooting

### Pre-flight failures

The wrapper checks prerequisites before starting any agent. Common failures:

| Error | Fix |
|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN is not set` | Run `claude setup-token` and export the token, or add it to `.harness/.env.local`. |
| `gh auth status` fails | Run `gh auth login` on the host. |
| Docker daemon not running | Start Docker Desktop. |
| `Missing config key: image` | Check `.harness/config.yml` for required keys. |
| Branch `kanban-issueN-*` already exists | Another terminal already claimed the issue. Use `-Resume` to continue it, or pick a different issue. |

### Hooks not firing

Hooks are defined in the agent prompt templates (`prompts/plan.md`, `prompts/implement.md`, etc.) and only run inside the container. If a hook that you expected to run did not:

1. Check the log file: `.harness/logs/issue-{N}.log` (full container stdout).
2. Verify the hook script exists in the project and is executable.
3. Confirm `hooks` keys in `config.yml` reference paths relative to `/workspace` (the container mount point), not the host path.

### Log file location

| Log | Path |
|---|---|
| Implement run | `.harness/logs/issue-{N}.log` |
| Plan run | `.harness/logs/plan-{timestamp}.log` |
| Smoke test | `.harness/logs/smoke-test.log` |

`.harness/logs/` is gitignored except for `.gitkeep`. Logs persist between runs and are overwritten on each new run for the same issue number.

---

## Cost / rate-limit reality (Pro subscription)

- Pro has a **5-hour rolling message window**. A full four-phase run (plan + implement + review + merge) on a complex slice can consume 30–50% of the window.
- **One issue at a time.** Opening two terminals for the same issue will exhaust the rate limit before either finishes. Open a second terminal only after the first has committed its implement phase and the window budget allows it.
- If a run crashes mid-way, partial commits stay on the local branch. Use `-Resume` to continue — the agent reads the branch state and picks up from the last commit.
- The harness does not sleep, estimate remaining budget, or auto-retry. It surfaces the failure and prints the resume command. The operator decides when to resume.

---

## Files

| Path | Purpose |
|---|---|
| `Dockerfile` | Node 22 + Python 3 + git + gh + claude CLI; user `agent` (UID 1000). |
| `config.yml` | Per-project config (image tag, branch prefix, tracker, models, test commands). |
| `run.ps1` | Entry point — Windows/PowerShell. Full four-phase pipeline. |
| `run.sh` | Entry point — Linux/macOS/CI. Plan + implement. |
| `lib/*.{ps1,sh}` | Pure-function modules mirrored across PS and bash. |
| `prompts/{plan,implement,review,merge,smoke-test}.md` | Project-agnostic prompt templates with `{{KEY}}` substitution. |
| `tests/` | Pester (`.Tests.ps1`) and bats (`.bats`) coverage for every `lib/` module. |
| `.env.local` | OAuth token override (gitignored). Copy from `.env.local.example`. |
| `logs/` | Per-run container stdout (gitignored except `.gitkeep`). |
