# ADR 0008: Generic agent harness is sequential, subscription-auth, and config-driven

**Status:** Accepted
**Tracking PRD:** [PRD 0002](../prd/0002-generic-agent-harness.md) — issue [#27](https://github.com/PaynePew/qr_code_generator/issues/27)

## Context

The repo currently carries two agent harness attempts that share a problem (drive `claude` against a GitHub issue end-to-end) but make different trade-offs:

- `.sandcastle/` — parallel within a single invocation (`Promise.allSettled` over N issues), API-key authentication, TypeScript orchestrator depending on `@ai-hero/sandcastle`, per-project prompts that hardcode test commands.
- `.harness/` — sequential within an invocation, subscription auth via `~/.claude/.credentials.json` bind-mount, PowerShell-only, prompts hardcoded to `qr_code_generator` paths.

Neither shape is suitable as a long-term general harness. `.sandcastle/` cannot be authenticated against a Pro/Team subscription, and its parallelism exceeds what a Pro subscription's 5-hour rolling message window can sustain. `.harness/` works on subscription auth today but doesn't travel: the bind-mount path is Windows-specific, the prompts contain `frontend/` / `backend/` baked in, and there is no plan or merge phase. Reusing either harness in a second project means forking and rewriting.

The harness shape was considered along three axes:

**Axis 1 — Authentication:**

1. **API key** (sandcastle). Direct Anthropic API, billed per-request. Requires an API key the operator does not have at scale.
2. **Credentials-file bind-mount** (current `.harness/`). Works for subscription auth but ties the harness to a host filesystem layout and fails in CI (no `~/.claude/.credentials.json` on a fresh runner).
3. **`CLAUDE_CODE_OAUTH_TOKEN` env var** (chosen). Long-lived token from `claude setup-token`, single env var, portable across hosts and CI, the path Anthropic recommends for headless use.

**Axis 2 — Concurrency:**

1. **Parallel within invocation** (sandcastle). Throughput scales with N. Rate-limit math under subscription auth makes it non-viable: a single Pro window cannot sustain N concurrent agents on the same account.
2. **Strictly sequential, no parallel terminals.** Simplest, but caps throughput at one issue per cycle.
3. **Sequential per terminal + opportunistic manual parallelism** (chosen). The wrapper runs one phase at a time within an invocation; the operator may open additional terminals when the rate-limit budget allows it. The plan phase deconflicts against in-progress work on the host so two terminals never claim the same issue.

**Axis 3 — Per-project shape:**

1. **Fork-and-rewrite per project** (current `.harness/` reality). Prompts, Dockerfile, and wrappers duplicate and drift across repos.
2. **Hardcoded shared base with per-project hooks only.** Limits what each project can customize; common shapes (different test command, different doc paths, different branch prefix) require code changes.
3. **Config-driven** (chosen). `.harness/config.yml` declares test/build commands, doc paths, branch prefix, per-agent models. Prompt templates use `{{KEY}}` placeholders substituted at orchestrate time. Agents never read the config — substitution happens host-side, so config values cost zero agent tokens.

Three constraints made the cross-product of these axes tractable:

- **Subscription auth (no API key)** mandates Axis-1.3 and effectively forbids Axis-2.1.
- **Multi-project portability** mandates Axis-3.3.
- **CI as a first-class operator** — the same harness must run on Windows Desktop, macOS, and `ubuntu-latest` — rules out Axis-1.2 and informs the PowerShell + Bash parity discipline captured in PRD 0002 Decision 10.

## Decision

The agent harness is **sequential per terminal, authenticated via `CLAUDE_CODE_OAUTH_TOKEN`, and configured via a per-project `.harness/config.yml`** with prompt-template substitution at orchestrate time. The pipeline is plan → implement → review → merge, run in series within one invocation. Manual parallelism is supported via independent terminal invocations on the same host; the plan phase deconflicts against local branches matching `{prefix}-issue*-*` and against `gh pr list`, and the first phase to `git checkout -b` is the atomic claim.

Operator-facing invariants pinned by this ADR:

- **Subscription auth only.** No API key path, no Anthropic API URL hardcoded. `CLAUDE_CODE_OAUTH_TOKEN` is read from shell env, falling back to `.harness/.env.local` (gitignored).
- **One terminal = one in-flight phase at a time.** The wrapper does not fan out within an invocation. Cross-terminal coordination is via local branch state and `gh pr list`, not via a daemon or a shared queue.
- **Generic by config, not by fork.** Prompts, wrappers, and Dockerfile are project-agnostic. All project-specific surfaces (test commands, doc paths, branch prefix, models) live in `config.yml`.
- **The issue body is never mutated.** AC checkbox state remains a human signal. Agents self-report in comments only.
- **Merge phase ends at `git push -u origin {branch} && gh pr create --fill`** with `Closes #N` in the body. The agent never `gh issue close`s, never merges to main, never `--auto-merge`s.

The full implementation contract — module shape, file layout, flag set, prompt structure, test plan — lives in PRD 0002. This ADR captures the load-bearing why and what alternative shapes were rejected.

## Consequences

- **Throughput is operator-bounded, not architecturally bounded.** A single terminal sustains a handful of slices per 5-hour Pro window (varies by slice complexity and turn count). Opening additional terminals scales linearly until the window's message budget is exhausted, after which all terminals begin hitting rate limits. The harness surfaces rate-limit failures cleanly with an exact resume command; it does not silently sleep, does not auto-retry, does not estimate remaining budget. The operator decides when to add or stop terminals.
- **Multi-project adoption is `cp .harness/ + edit config.yml`, not a fork.** Prompts, Dockerfile, wrappers, and `lib/` modules travel unchanged. Drift across projects is bounded by config differences, not by parallel evolution of forked prompts. New projects benefit from upstream harness improvements by `git pull`-ing the harness directory.
- **PowerShell + Bash parity is the structural maintenance cost.** Every CLI flag, every output format, every `lib/` module change must land in both `run.ps1` and `run.sh`. Pester (PS) and bats-core (Bash) test suites are required for both sides on every PR. Mitigated by keeping wrappers thin (~150 lines) and pushing real logic into testable `lib/` modules — but the cost is real and persistent. A future migration to a single-language orchestrator (Deno, Bun, Python) could collapse the parity discipline, but is not in scope for v1.
- **Manual issue-tracker mutation is the merge gate.** AC checkboxes stay empty until a human ticks them when merging the PR. The agent's self-report comment is a convenience, not a substitute. Auto-merge to main and auto-close of issues are explicitly out of scope. Removing these invariants requires revisiting this ADR.
- **`.sandcastle/` is superseded for this project.** Its parallelism and TS orchestrator do not pay for themselves under subscription auth. A future cleanup PR may retire `.sandcastle/` once the new harness is in production use. The four-phase prompt structure was inspired by `.sandcastle/prompts/` but is not reused verbatim — the new prompts are project-agnostic via `{{KEY}}` substitution, drop the API-specific `<promise>COMPLETE</promise>` discipline in favor of structured issue comments, and add the dirty-tree-on-resume contract.
- **Generic implies losing some QR-specific affordances.** The current `.harness/prompts/implement.md` hardcodes paths to `/workspace/docs/frontend-prd.md` and `/workspace/CONTEXT.md`. The new prompts substitute these from config, so a project without a `CONTEXT.md` drops that line cleanly rather than referencing a missing file. Projects that *do* have it gain the same behavior; nothing in the QR project regresses, but the QR-specific docstrings become slightly more abstract.
- **CI portability earned only by twin scripts.** Without `run.sh`, the harness cannot run on `ubuntu-latest` in GitHub Actions or on a Mac contributor's laptop. The PowerShell + Bash twin contract is the path of least new dependencies.
- **Tracker pluggability is deferred.** `tracker.type` in config is reserved for Linear/Jira/GitLab, but only `github` is implemented. The `gh` commands live in the prompt templates, not in an abstraction layer. The abstraction is earned when a second tracker is integrated, not before. Adding Linear later means writing `prompts/plan.linear.md` (etc.) and routing on `tracker.type`, not refactoring an existing abstraction.
- **No persistent state outside git.** Resume reads the branch and the host-side log file. There is no `.harness/state.json` to drift, lose, or contend with under cross-terminal parallelism. The branch is the source of truth. A failed run leaves WIP commits on the branch; a fresh run with `-Resume` continues from where it stopped.
- **Three-layer self-review safety is structural, not a runtime check.** Different default models per phase (Sonnet implement / Opus review), different prompts (doer vs critic), and fresh container per phase together prevent implement-style reasoning from contaminating review. The wrapper warns (not blocks) when config assigns the same model to both phases, so cost-constrained operators retain the override.
- **Subscription-auth lock-in is intentional.** The harness deliberately does not offer an API-key path. Adding one would re-introduce the abuse window that justified the subscription-only choice, and would require splitting the prompts and wrapper logic on auth mode. Operators who later want API-based throughput build a parallel orchestrator (the original `.sandcastle/` model is the reference) rather than retrofit this one.
