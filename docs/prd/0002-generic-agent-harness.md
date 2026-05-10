# PRD 0002: Generic Docker Agent Harness

**Status:** Ready for agent
**Tracking issue:** [#27](https://github.com/PaynePew/qr_code_generator/issues/27)
**ADR:** [0008 — Generic agent harness is sequential, subscription-auth, and config-driven](../adr/0008-generic-agent-harness.md)
**Related:** Current `.harness/` (project-specific 2-phase) and `.sandcastle/` (parallel 4-phase, API-based) — both superseded by this design.

**Implementation slices:**
- [#28 — Slice 1](https://github.com/PaynePew/qr_code_generator/issues/28) — Harness skeleton + smoke test (tracer bullet)
- [#29 — Slice 2](https://github.com/PaynePew/qr_code_generator/issues/29) — Plan phase (blocked by #28)
- [#30 — Slice 3](https://github.com/PaynePew/qr_code_generator/issues/30) — Implement phase (blocked by #29)
- [#31 — Slice 4](https://github.com/PaynePew/qr_code_generator/issues/31) — Review phase (blocked by #30)
- [#32 — Slice 5](https://github.com/PaynePew/qr_code_generator/issues/32) — Merge phase (blocked by #31)
- [#33 — Slice 6](https://github.com/PaynePew/qr_code_generator/issues/33) — Advanced config: hooks, `when:`, `agents` block (blocked by #28)
- [#34 — Slice 7](https://github.com/PaynePew/qr_code_generator/issues/34) — CI parity + README + retire legacy harnesses (HITL, blocked by #28–#33)

Local issue body copies live alongside in [`0002-slices/`](./0002-slices/).

---

## Problem Statement

The current `.harness/` directory is functional but constrained: it implements a 2-phase pipeline (implement → review) tightly coupled to the QR Code Generator project's file layout (`frontend/`, `backend/`), test commands (`npm test --prefix frontend`, `pytest backend/`), and doc paths (`/workspace/docs/adr/`). Prompts hard-code project-specific references. Reusing this harness on another project requires forking and rewriting the prompts and wrapper, with no shared upgrade path.

`.sandcastle/` provides the missing capabilities — a 4-phase plan/implement/review/merge pipeline with multi-issue planning — but at significant cost: it depends on the Anthropic API (incompatible with subscription-only authentication), it builds parallelism that exceeds what a Pro subscription's 5-hour rolling window can sustain, and its TypeScript orchestrator (`@ai-hero/sandcastle`) introduces dependencies and complexity that block easy adoption in non-Node projects.

Additionally, both existing harnesses surface several operator-experience gaps:

- Verbose stream-json output dominates the terminal during long runs, making the "what is the agent doing right now" signal hard to read at a glance.
- The implement agent silently produces no GitHub issue comment on successful completion (only on partial failures), so the operator has no end-of-run record outside the branch itself.
- No mechanism guarantees that a new agent run won't pick up an issue that another terminal already started — manual coordination is required.
- Resume after a rate-limit failure or crash is unergonomic; the operator must manually inspect the branch and decide what to re-run.

The operator needs a single harness configuration that travels across projects, respects subscription auth, gives clear feedback during runs, leaves clear records on every issue, and supports both unattended single-issue runs and opportunistic manual parallelism.

## Solution

Ship a generic, config-driven Docker agent harness that any project can adopt by dropping a `.harness/` directory into its root and writing a `config.yml` describing its test/build commands and doc layout. The harness orchestrates a four-phase pipeline (plan → implement → review → merge) using subscription authentication (`CLAUDE_CODE_OAUTH_TOKEN`), sequentially per terminal, with manual parallelism supported via independent terminal invocations and atomic branch-claim deconfliction.

The wrapper ships two thin entry points — `run.ps1` for Windows and `run.sh` for macOS/Linux/CI — that share a single underlying Dockerfile, a single set of prompt templates, and a single `lib/` of pure-function modules (prompt templater, config loader, plan output parser, deconflict scanner, image cache check, heartbeat reducer). All project-specific surfaces are declared in `config.yml` and substituted into prompts at orchestrate time; agents never read the config directly, keeping per-phase token cost low.

The terminal renders only a static header plus a single in-place updating heartbeat line; full stream-json output goes to a host-side log file named after the branch and agent. Every run posts a structured comment to the GitHub issue with commits, AC self-report, and notes — never mutating the issue body so AC checkboxes remain a meaningful human merge gate. Merge phase ends at "branch pushed + PR opened with `Closes #N`" — never auto-merging to main and never auto-closing the issue. On rate-limit or crash, the wrapper surfaces a clean message with the exact resume command.

The harness is intentionally **not** a Sandcastle replacement: no parallelism within a single invocation, no automatic merge, no orchestrator daemon. Operator presence remains the central control point. Future parallelism, if needed, layers on additively via a queue runner around the existing invocation contract.

## User Stories

### Project owner (adopting the harness)

1. As a project owner, I want to copy `.harness/` from a reference project into my new repo and adjust only `config.yml`, so that I can get a working agent harness without rewriting prompts or wrapper logic.
2. As a project owner on a flat-layout project (no `frontend/` / `backend/`, just `main.py` at root), I want the test config to apply unconditionally without scaffolded directory predicates, so that the harness works on my project without artificial structure.
3. As a project owner adding Go (or any non-Node, non-Python runtime) to the toolchain, I want to extend the base Docker image with `FROM agent-harness:latest` and a few `RUN` lines, so that I can add language runtimes without forking the base.
4. As a project owner, I want the harness to skip references to docs that don't exist in my project (e.g., no `CONTEXT.md`, no `docs/adr/`), so that I don't have to fabricate empty files to satisfy the prompts.
5. As a project owner, I want CODING_STANDARDS to layer (universal rules in the prompt + my project-specific overlay), so that I get a baseline review rubric without writing every rule from scratch.
6. As a project owner, I want to override the model used for any phase via `config.yml`, so that I can favor speed (Sonnet) or depth (Opus) per phase based on my project's needs and budget.

### Operator (running the harness daily)

7. As an operator, I want to run `pwsh ./.harness/run.ps1` with no flags and have it pick the next-best issue for me, so that I don't have to triage the backlog manually every time.
8. As an operator, I want the harness to show me the plan's top candidate with reasoning and ask "Run it? [Y/n]" before starting, so that I can override its pick without ceding all control.
9. As an operator running unattended (overnight, scheduled), I want a `-Yes` flag that skips the confirmation prompt, so that the harness can run hands-off.
10. As an operator, I want to bypass the plan phase with `-Issue N` and jump straight to implementing a specific issue, so that I can pick the issue manually when I already know what I want to work on.
11. As an operator running multiple terminals in parallel, I want each terminal's plan phase to exclude issues that another terminal is already working on, so that two agents never collide on the same branch.
12. As an operator, I want to inspect plan's full candidate ranking without committing to a run via `-Plan`, so that I can preview the backlog state.
13. As an operator whose run was interrupted mid-implement (rate limit, crash, host reboot), I want to resume with `-Issue N -Resume`, so that the agent picks up from existing commits on the branch rather than starting over.
14. As an operator on a long-running implement phase, I want the terminal to show a single updating heartbeat line (turns, elapsed, last action), so that I know the agent is alive without a wall of streaming events.
15. As an operator, I want the full event stream saved to a per-run log file on the host, so that I can post-mortem any run by reading the log without needing the container to still be running.
16. As an operator, I want every completed implement and review phase to post a structured comment on the GitHub issue, so that I have an issue-level record of what was done even when I'm not at the terminal during the run.
17. As an operator, I want the agent to never auto-tick AC checkboxes in the issue body, so that the unticked-box-equals-incomplete signal remains my reliable merge gate.
18. As an operator, I want the merge phase to push the branch and open a PR with `Closes #N`, but never merge to main itself, so that GitHub's diff view and my human eyeballs remain the final gate.
19. As an operator, I want a clean final summary at the end of every run (success or failure) with the branch name, PR link, and next-step commands, so that I know exactly what to do next.
20. As an operator hitting a subscription rate-limit mid-phase, I want the wrapper to detect it and print the exact resume command, so that I don't waste time diagnosing whether to retry or debug.

### Contributor / harness maintainer

21. As a contributor maintaining the harness, I want the wrapper's prompt-templating, config-loading, plan-parsing, deconflict-scanning, image-cache, and heartbeat-rendering logic split into discrete `lib/` modules, so that each can be unit-tested without spinning up Docker.
22. As a contributor, I want both PowerShell and Bash implementations of each `lib/` module to have an identical contract (same inputs, same outputs), so that parity tests catch drift between the two platforms.
23. As a contributor, I want a Pester suite for the PowerShell side and a bats-core suite for the Bash side, so that both platforms have CI coverage on every PR.
24. As a contributor, I want the wrapper scripts themselves to remain thin (~150 lines each) with all real logic in the `lib/` modules, so that the orchestration layer is easy to read and platform-port.
25. As a contributor, I want every project-specific reference in prompts to be a `{{KEY}}` placeholder substituted at orchestrate time, so that prompts are reusable across projects without forking.
26. As a contributor extending the harness, I want a small set of pre-defined hook lifecycle points (`before-tests`, `after-implement`) with minimal surface area, so that I can solve real needs without inheriting unused complexity.

### Future operator (resilience & evolution)

27. As an operator on a deployed harness, I want the Docker image to rebuild automatically when the Dockerfile changes (via hash check), so that I never run with a stale image after editing the Dockerfile.
28. As an operator who switches the model used for a phase, I want a warning when implement and review share the same model, so that I don't silently lose the cross-model self-review safety net.
29. As an operator, I want the same harness contract on my Windows laptop, my colleague's Mac, and our Linux CI runner, so that the harness behaves predictably regardless of where it runs.
30. As an operator with no Docker daemon running or no `CLAUDE_CODE_OAUTH_TOKEN` set, I want a pre-flight check to fail fast with a clear error and the exact remediation command, so that I'm not debugging an obscure failure five minutes into a run.

## Implementation Decisions

### Decision 1 — Concurrency model

Sequential per terminal invocation. The wrapper executes plan → implement → review → merge in series, one phase at a time, against a single working directory. Multiple terminals may run independently on the same host; deconfliction is the plan phase's responsibility (Decision 2). No `Promise.allSettled`-style parallelism within a single invocation. Rate-limit math under subscription auth forbids it; sequential discipline keeps the architecture portable and debuggable.

### Decision 2 — Deconfliction and branch claim

The plan phase's first step is enumerating in-progress work via local branches matching `{branch_prefix}-issue*-*` and `gh pr list --state open`. The plan agent receives this list and is prompted to reason about file overlap from issue bodies; it returns a top candidate plus alternatives. The wrapper presents the top candidate to the operator for Y/n confirmation. On confirmation, the implement phase enters and its first action is `git checkout -b {branch}` — this is the atomic claim. If a competing terminal raced through plan and picked the same issue, the second `checkout -b` fails on the existing branch and that terminal exits with a clear "already claimed" message. Plan itself is read-only and re-runnable.

### Decision 3 — Resume semantics

Explicit `-Resume` flag. There is no auto-detect of in-progress branches at startup — auto-resume could silently pick up a teammate's branch on a shared host. With `-Resume`, the wrapper skips plan, takes the issue number, asserts that a `{prefix}-issue{N}-*` branch exists locally, and enters implement against that branch. The implement prompt is already idempotent within a phase: it checks out the existing branch, reads `git status`, and continues from where commits left off. Review is naturally idempotent. The implement prompt is updated to handle dirty working trees by stashing or WIP-committing, never by `git reset --hard` without a summary line.

### Decision 4 — End-of-run reporting

Every implement and review phase posts a structured GitHub issue comment, unconditionally — on COMPLETE, BLOCKED, or any in-between state. The comment includes branch name, status, commit list with subjects, "What was built" bullets grounded in files, an AC self-report mirroring the issue's checkbox list (with claims and per-AC evidence), and any out-of-scope concerns. The agent **never** mutates the issue body. AC checkboxes in the body remain a human-only signal; the operator ticks them when reviewing the PR. This preserves "unticked box equals incomplete" as a reliable merge gate.

### Decision 5 — Authentication

Standardize on `CLAUDE_CODE_OAUTH_TOKEN` environment variable. The wrapper reads it from the shell environment first, then from `.harness/.env.local` (gitignored) as a fallback. The credentials-file bind-mount approach used by the current `.harness/` is dropped entirely — it ties the harness to a host filesystem layout and doesn't work in CI. The token is generated once via `claude setup-token` on the host and survives months; rotation is operator-controlled. Pre-flight fails with a specific error message and the exact remediation command if the token is missing.

### Decision 6 — Project configuration

A single `.harness/config.yml` per project, checked into the repository, declares: Docker image tag and optional custom Dockerfile path; branch prefix (default `kanban`; branch format `{prefix}-issue{N}-{slug}`); issue tracker type (v1: `github` only; `tracker.type` field reserved for future Linear/Jira/GitLab) and optional filter label; container `setup` commands; `tests` and `typecheck` command lists with optional `when:` predicates (omit = always apply, so flat-layout projects don't need conditional logic); domain doc paths (`context`, `adr_dir`, `prd_dir`) with auto-skip when absent; per-agent `model` and `max_turns` for plan/implement/review/merge; `commit_style` (default `conventional`).

The wrapper reads `config.yml` once at startup and substitutes values into prompt templates as `{{KEY}}` placeholders before passing prompts into the container. Agents do not read the config file — substitution happens host-side, so config values cost zero agent tokens. Default per-agent models: plan and review on Opus 4.7, implement and merge on Sonnet 4.6. CLI flags (e.g., `-ReviewModel`) override config; config overrides built-in defaults.

### Decision 7 — Merge phase scope

Merge phase performs three concrete actions and stops: (1) verify branch is clean and tests pass, (2) `git push -u origin {branch}`, (3) `gh pr create --fill` with a body containing `Closes #N`, commit summary, AC self-report, and reviewer notes; then comments on the issue with the PR link. The merge phase **does not** `git merge` to main, does not run `gh issue close`, does not `--auto-merge`, and does not squash or rebase. GitHub closes the issue when the human merges the PR via the `Closes #N` keyword. Auto-merge contradicts the AC-checkbox-as-human-gate decision and is one rate-limit failure from leaving main broken.

### Decision 8 — Wrapper invocation surface

Single command per platform. Flags:

| Flag (PS / Bash) | Behavior |
|---|---|
| (none) | Plan → confirm → implement → review → merge |
| `-Yes` / `--yes` | Plan → auto-confirm top candidate → implement → review → merge |
| `-Issue N` / `--issue N` | Skip plan; implement → review → merge on issue #N |
| `-Issue N -Resume` / `--issue N --resume` | Skip plan; resume on existing `{prefix}-issue{N}-*` branch |
| `-Plan` / `--plan` | Plan only; print ranked candidates; exit |
| `-SkipReview` / `--skip-review` | Omit review phase |
| `-SkipMerge` / `--skip-merge` | Omit merge phase (commits stay local) |

Declining the confirmation prompt exits cleanly with no leftover branches or state.

### Decision 9 — Terminal and log output

The terminal prints a static header at run start (issue, agent, model, branch, log path) followed by a single in-place updating heartbeat line driven by stream-json events parsed host-side: `turns N/M · elapsed Xs · last <short description of last tool/action>`. The header's `Agent:` line changes when the phase transitions (implement → review → merge). Final exit replaces the heartbeat with a status line (`COMPLETE` or specific failure reason). The full stream-json output is teed from `docker run`'s stdout to a host-side log file at `.harness/logs/{branch}-{agent}.log`. On rerun, a pre-existing log is rotated to `{...}.prev.log` (one generation kept). The log file exists and grows on the host throughout the run — no post-hoc copy from inside the container.

### Decision 10 — Module shape

The orchestrator splits into six pure-function modules under `.harness/lib/`, each mirrored in PowerShell and Bash with an identical contract:

| Module | Responsibility | Contract |
|---|---|---|
| **Prompt templater** | Substitute `{{KEY}}` placeholders. Drop a line entirely when its substitution resolves to empty (so missing CONTEXT.md doesn't leave broken references). | `render(template_text, substitutions) → rendered_text` |
| **Config loader** | Parse `.harness/config.yml`, validate required keys, apply defaults, evaluate `when:` predicates against the working directory. | `load(yaml_text, repo_root) → resolved_config` |
| **Plan output parser** | Extract the `<plan>...</plan>` JSON from claude stdout, validate `top` / `alternatives` / `blocked` shape, return a typed struct or a parse error. | `parse(stdout) → plan_result \| parse_error` |
| **Deconflict scanner** | Enumerate in-progress issue numbers from local `{prefix}-issue*-*` branches plus open PRs from `gh pr list`. Returns a set of integers to exclude. | `scan(repo_root, prefix) → set<int>` |
| **Image cache check** | Hash the Dockerfile, compare to a marker file in `.harness/.image-hash`, decide whether to rebuild. Triggers when image is missing or the hash differs. | `should_rebuild(dockerfile_path, marker_path, image_tag) → bool` |
| **Heartbeat reducer** | Pure function from a single stream-json event to a status state update (`turns`, `elapsed_s`, `last_action`). | `reduce(state, event) → new_state` |

The wrapper scripts themselves contain only shallow orchestration glue: argument parsing, pre-flight checks, `docker run` invocation, tee-to-log, and final-summary printing. Each wrapper is approximately 150 lines.

### Decision 11 — Token economy

Phase-specific eager-load rules:

- **Plan**: open issues (filtered by `tracker.filter_label`) + in-progress branch list + open PR list + ADR filenames (titles only, not bodies).
- **Implement**: issue body + parent PRD if referenced; CONTEXT.md and ADR bodies read lazily.
- **Review**: diff + commit log + CONTEXT.md + ADR filenames + universal review rubric + project CODING_STANDARDS overlay; ADR bodies read lazily.
- **Merge**: diff + commit log + tests output; no doc loading.

PRDs (~200 lines, ~2,500 tokens, ~1.25% of context window) are inexpensive enough to load eagerly during implement. ADR directories at scale (20+ files) are not.

### Decision 12 — Self-review safety

Three structural layers prevent implement-style reasoning from contaminating review:

1. **Different models by default** — implement on Sonnet, review on Opus. Different training distributions surface different blind spots.
2. **Different prompts** — implement is a doer prompt ("make AC pass, write tests, commit"); review is a critic prompt ("check correctness first, then clarity, never change behavior").
3. **Fresh container per phase** — each phase runs in a separate `docker run --rm`. Reviewer has zero memory of the implementer's intermediate reasoning; it reads only the committed diff.

The wrapper emits a pre-flight warning (not a hard block) if `config.yml` assigns the same model to both phases. Token-budget-constrained users can override; the default config nudges toward the safe split.

### Decision 13 — Failure handling

Each phase failure (non-zero exit, rate-limit detection, partial commits) skips all subsequent phases and prints a phase-specific recovery instruction in the final summary. The wrapper detects rate-limit failures by grepping the log for `Rate limit exceeded` or `usage_limit_exceeded` substrings and surfaces a "resume with `-Issue N -Resume`" hint. There is no auto-retry, no auto-sleep-until-window-resets. Branch commits remain in place so resume actually works. The final summary box is printed for every run — success or failure — with the branch name, log path, PR link if applicable, and the literal next command.

### Decision 14 — Image lifecycle

The wrapper hashes `.harness/Dockerfile` at startup and compares to a marker file (`.harness/.image-hash`, gitignored). Build is triggered when the image is missing OR the hash differs. For projects with a custom Dockerfile (`dockerfile:` set in config), the same logic applies against that file and its image tag. The build runs against `.harness/` as context. The marker file lives outside version control so each developer has independent build state.

### Decision 15 — Hooks lifecycle

Two host-side hook points for v1, both optional, both non-blocking (a failing hook logs a warning and the run continues):

- `.harness/hooks/before-tests.sh` — runs before any phase invokes the project's test command (useful for regenerating fixtures, seeding a test DB).
- `.harness/hooks/after-implement.sh` — runs after the implement phase exits successfully (useful for project-specific linting / formatting checks).

Both run on the host (not inside the container) with the repo root as `cwd` and `HARNESS_ISSUE`, `HARNESS_BRANCH`, `HARNESS_PHASE` env vars set. Additional lifecycle points are deferred until a concrete need surfaces.

### Decision 16 — File layout

```
.harness/
├── run.ps1                     # Windows entry
├── run.sh                      # *nix entry
├── config.yml                  # per-project config (checked in)
├── Dockerfile                  # base image
├── CODING_STANDARDS.md         # optional per-project overlay
├── prompts/{plan,implement,review,merge}.md
├── lib/                        # pure modules, mirrored PS + bash
│   ├── render-prompt.{ps1,sh}
│   ├── load-config.{ps1,sh}
│   ├── parse-plan.{ps1,sh}
│   ├── scan-deconflict.{ps1,sh}
│   ├── image-cache.{ps1,sh}
│   └── heartbeat.{ps1,sh}
├── hooks/{before-tests,after-implement}.sh    # optional
├── logs/.gitkeep                              # logs themselves gitignored
├── .env.local                  # gitignored
├── .image-hash                 # gitignored
├── .gitignore
└── README.md
```

## Testing Decisions

### What makes a good test, in this harness

- Test external behavior, not internal state. For the prompt templater, that means: given (template_text, substitutions), assert rendered_text. Do not assert on intermediate parsing state.
- The wrapper scripts themselves are not unit-testable; their job is orchestration glue and `docker run` invocation. Validate them by hand-driven smoke tests against a known issue. Unit-test the deep modules they use.
- Mock external commands (`git`, `gh`, `docker`) by feeding stdin/stdout fixtures to the deconflict scanner and image cache check. Do not run real `git` or `gh` from tests.
- Avoid Docker-in-CI for unit tests. Reserve Docker for the smoke-test path that runs on demand.
- PowerShell tests use Pester (de-facto standard). Bash tests use bats-core (lightweight, no extra dependencies beyond bash).

### Modules to be tested

All six deep modules are tested on both platforms.

| Module | Test file (PS) | Test file (Bash) | Style |
|---|---|---|---|
| **Prompt templater** | `tests/render-prompt.Tests.ps1` | `tests/render-prompt.bats` | Pure-function unit tests. Cover: simple `{{KEY}}` substitution; multiple keys; missing-substitution behavior (drop line vs preserve placeholder); whitespace handling; idempotent re-render. |
| **Config loader** | `tests/load-config.Tests.ps1` | `tests/load-config.bats` | Schema validation + predicate evaluation. Cover: minimal valid config; default-filling; missing required key surfaces clear error; `when: exists(...)` predicate against a fixture directory tree (both true and false); empty `tests:` list; per-agent model + max_turns precedence (CLI > config > default). |
| **Plan output parser** | `tests/parse-plan.Tests.ps1` | `tests/parse-plan.bats` | Robust JSON extraction. Cover: well-formed `<plan>{...}</plan>` block; multiple `<plan>` blocks (use last); malformed JSON inside `<plan>` returns parse-error; missing `top` key surfaces validation error; empty `alternatives` is valid; surrounding noise tolerated. |
| **Deconflict scanner** | `tests/scan-deconflict.Tests.ps1` | `tests/scan-deconflict.bats` | Mock `git` and `gh` stdout. Cover: no in-progress work returns empty set; single local branch returns that issue number; multiple local branches; open PR for a non-local branch is still excluded; malformed branch name (no issue number) is skipped without error; `gh` command failure falls back gracefully on local-only. |
| **Image cache check** | `tests/image-cache.Tests.ps1` | `tests/image-cache.bats` | File-fixture tests. Cover: image present + matching hash → no rebuild; image present + hash mismatch → rebuild; image absent → rebuild regardless; missing marker file → rebuild; corrupted marker file → rebuild (and overwrite). |
| **Heartbeat reducer** | `tests/heartbeat.Tests.ps1` | `tests/heartbeat.bats` | Pure reducer over sequence of events. Cover: `system.init` event sets initial state; `assistant.text` events update last_action with truncated text; `tool_use` events update last_action with `[tool] name`; `result` event sets terminal turn count and duration; events arriving in unexpected order do not crash. |

### Prior art

- This codebase already follows the "one test file per module" convention in `tests/test_rate_limiter_*`. The harness tests follow the same file-per-module pattern under `.harness/tests/`.
- Pester and bats-core are not yet present in this repo, so they will be introduced as new test framework dependencies — Pester via PowerShell module install, bats via system package or git submodule.

### Out of scope for the test plan

- End-to-end test that spins up Docker, runs claude against a real issue, and asserts on commits. Costs subscription tokens and depends on network and live LLM behavior — not a per-PR test. Reserved for an operator-run smoke test against a known fixture issue.
- Cross-platform parity tests asserting that the PS and Bash implementations of each module produce byte-identical output. Behaviorally equivalent is the contract; byte parity is not required (e.g., line endings may differ).

## Out of Scope

- **Parallelism within a single invocation.** Subscription auth's 5-hour message window does not sustain N concurrent agent runs against the same account. Manual parallelism via independent terminals is supported by deconfliction (Decision 2); intra-invocation parallelism is not. If true parallelism is later required, it layers on additively via a queue runner around the existing invocation contract.
- **Non-GitHub issue trackers (Linear, Jira, GitLab).** `tracker.type` in config is reserved for the future but only `github` is implemented in v1. Adding a tracker means writing a parallel set of prompts (`prompts/plan.linear.md` etc.) and wiring the wrapper to pick by `tracker.type`. Premature without a concrete second tracker to validate the abstraction.
- **Auto-merge to main.** Decision 7 is explicit: merge phase ends at PR open. Auto-merge contradicts the AC-checkbox-as-human-gate design and is one rate-limit failure from leaving main broken.
- **Auto-tick of AC checkboxes in issue bodies.** Decision 4 keeps AC checkboxes as a manual human signal. Agent self-reports go in comments only.
- **Multi-issue planning per invocation.** Plan picks one issue per run. The plan phase outputs alternatives so the operator can override the top choice, but the run only ever progresses one issue end-to-end.
- **Persistent state files outside git.** The branch itself is the state. Resume reads the branch and the log file; no separate state JSON is introduced.
- **Wrapper-level metrics, dashboards, telemetry.** No metrics infra exists in projects that adopt this harness by default. Adding it for one counter is premature; project owners who want telemetry add it via hooks.
- **Admin / runtime configuration endpoint.** Configuration changes happen by editing `config.yml` and re-running; no API.
- **A bundled "next-tracker" abstraction.** The current `gh` calls live in prompt templates, not in an abstraction layer. The abstraction will be earned when a second tracker is integrated.

## Further Notes

- **The current `.harness/` is the proof-of-concept.** It validated subscription auth via OAuth credentials, the two-phase implement/review pattern, the bind-mount-credentials approach, and the host-side `Tee-Object` log strategy. This PRD generalizes those wins and adds the missing plan/merge phases plus deconfliction, resume, structured reporting, and generic config.
- **The `.sandcastle/` directory is the comparison point for the four-phase pipeline.** Its plan/implement/review/merge prompts inspire the prompt structure here, but the orchestrator is rewritten in PowerShell + Bash rather than TypeScript, and the auth model switches from API key to `CLAUDE_CODE_OAUTH_TOKEN`. After this PRD lands, `.sandcastle/` becomes redundant for this project and a future cleanup PR can retire it.
- **The default per-agent models (plan & review on Opus 4.7, implement & merge on Sonnet 4.6) are starting points.** Expect tuning based on observed agent quality per phase. The `agents:` section in `config.yml` is the operator's tuning knob; CLI flags allow per-run overrides without editing config.
- **The two-script (PowerShell + Bash) parity discipline is the only structural cost of the harness.** Every flag change, every output format change, must land in both files. Smoke-testing on both platforms after any change to `lib/` or `run.*` is the discipline that keeps drift bounded. CI on the matrix catches the rest.
- **This PRD intentionally specifies operator-experience invariants alongside implementation decisions.** The "terminal only shows current issue + agent" requirement, the "every run posts an issue comment" requirement, and the "resume is explicit" requirement are not implementation details — they are the contract the harness ships against, and they should not be relaxed without revisiting this PRD.
