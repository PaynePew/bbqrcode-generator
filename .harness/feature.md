# Generic Docker Agent Harness — design references

> This file was originally a scratchpad. The design has been formalized and now lives in the documents below. Edit those, not this file.

## Canonical sources of truth

- **PRD 0002 — Generic Docker Agent Harness:** [`docs/prd/0002-generic-agent-harness.md`](../docs/prd/0002-generic-agent-harness.md)
  - GitHub tracking issue: [#27](https://github.com/PaynePew/qr_code_generator/issues/27) (labeled `ready-for-agent`)
  - Captures: problem statement, solution, 30 user stories, 16 implementation decisions, testing plan for all six deep modules, out-of-scope list

- **ADR 0008 — Generic agent harness is sequential, subscription-auth, and config-driven:** [`docs/adr/0008-generic-agent-harness.md`](../docs/adr/0008-generic-agent-harness.md)
  - Captures the load-bearing trade-offs: subscription auth vs API key, sequential vs parallel concurrency, config-driven vs project-fork
  - Documents what alternative harness shapes were considered and rejected

## What this directory is becoming

The current `.harness/` contents (`Dockerfile`, `run-issue.ps1`, `run-hello.ps1`, `prompts/implement.md`, `prompts/review.md`, `CODING_STANDARDS.md`, `README.md`) are the **proof-of-concept** that validated subscription auth, the two-phase implement+review pattern, and the host-side log-tee strategy. They will be replaced by the implementation described in PRD 0002:

- `run.ps1` + `run.sh` — twin entry points (Windows and *nix/CI)
- `config.yml` — per-project config that drives prompts, models, test commands, doc paths
- Four-phase prompts: `prompts/{plan,implement,review,merge}.md` — project-agnostic with `{{KEY}}` substitution
- `lib/` — six pure-function modules (prompt templater, config loader, plan output parser, deconflict scanner, image cache check, heartbeat reducer), each mirrored in PowerShell and Bash
- `hooks/` — optional `before-tests.sh` and `after-implement.sh` host-side hooks
- Test suites (Pester + bats-core) covering all six `lib/` modules on both platforms

## Originating brief (historical)

The original scratch was a short Chinese-language brief asking for:

- A subscription-auth Docker harness similar to `.sandcastle/` but using `CLAUDE_CODE_OAUTH_TOKEN` (no API key)
- Project-agnostic so it can be reused beyond `qr_code_generator`
- A four-phase pipeline: plan → implement → review → merge
- Lightweight Docker, minimal token burden
- Logs synced from container to host
- Terminal shows only the current issue and the executing agent

Every one of those requirements is preserved in PRD 0002. The PRD adds the operational details (resume semantics, end-of-run reporting, deconfliction, failure handling, image lifecycle) that emerged from the design grilling.

## Implementation entry point

When work starts, the first slice issue (split out via `/to-issues` against PRD #27) should land:

1. The base `Dockerfile` and `config.yml` schema
2. The `lib/` modules in both PS and Bash, with Pester + bats tests
3. The thin `run.ps1` and `run.sh` wrappers wired against the modules
4. One of the four phase prompts (plan first, since the pipeline starts there) to validate end-to-end

Each subsequent slice extends a phase or adds a feature. The vertical-slice discipline from PRD 0001's issues (#23–#26) is the model.
