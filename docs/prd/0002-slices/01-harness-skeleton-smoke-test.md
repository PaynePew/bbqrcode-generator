## Parent

PRD 0002 — Generic Docker Agent Harness ([#27](https://github.com/PaynePew/qr_code_generator/issues/27)) · ADR [0008](../../adr/0008-generic-agent-harness.md)

## What to build

A minimal end-to-end harness skeleton that runs a smoke-test "claude says PONG" prompt inside Docker via subscription auth, with the foundational `lib/` modules and pre-flight checks in place. This is the tracer bullet — it cuts through every architectural layer (Dockerfile, config, lib, prompt template, wrapper, log, terminal output) at minimum width.

Operator workflow it enables: `pwsh ./.harness/run.ps1 -SmokeTest` (or `./.harness/run.sh --smoke-test`) builds the image if needed, starts a `--rm` container, runs `claude -p "Reply PONG"` with `CLAUDE_CODE_OAUTH_TOKEN`, tees stdout to `.harness/logs/smoke-test.log`, and prints the final summary box with `COMPLETE`. Rebuilds happen only when the Dockerfile hash changes.

The smoke-test phase exists specifically to validate the plumbing without consuming agent tokens on a real issue. It is permanent infrastructure, not throwaway scaffolding.

## Acceptance criteria

- [ ] Base `.harness/Dockerfile` exists with: Node 22, Python 3, git, gh, jq, claude CLI installed; non-root `agent` user (UID 1000) with home at `/home/agent`; `WORKDIR /workspace`; renames base image's `node` user via `usermod`/`groupmod`. No project-specific dependencies baked in.
- [ ] `.harness/config.yml` schema documented and example committed for `qr_code_generator`. Minimum required keys: `image`, `branch_prefix`, `tracker.type` (only `github` accepted in v1). All other keys optional with sensible defaults.
- [ ] `.harness/lib/load-config.{ps1,sh}` parses YAML, validates required keys, applies defaults, surfaces clear error on missing required key. Same contract on both platforms.
- [ ] `.harness/lib/render-prompt.{ps1,sh}` substitutes `{{KEY}}` placeholders in a template string. A line whose substitution resolves to empty is dropped entirely (so missing CONTEXT.md does not leave a broken reference). Same contract on both platforms.
- [ ] `.harness/lib/image-cache.{ps1,sh}` compares Dockerfile hash to a marker file (`.harness/.image-hash`, gitignored) and returns whether to rebuild. Returns true on missing image, missing marker, hash mismatch, or corrupted marker.
- [ ] Pester tests for the three PS lib modules under `.harness/tests/` covering all stated contracts.
- [ ] bats-core tests for the three bash lib modules under `.harness/tests/` covering all stated contracts.
- [ ] `.harness/run.ps1` and `.harness/run.sh` exist (~150 lines each) with shared behavior: pre-flight checks (`CLAUDE_CODE_OAUTH_TOKEN` from env or `.harness/.env.local`, docker daemon, `gh auth`, git repo), load config, render prompt, image-cache check, `docker run` with bind-mount + env var, tee stdout to host log file, print final summary box.
- [ ] `.harness/prompts/smoke-test.md` exists with a single instruction: "Reply with the word PONG and nothing else."
- [ ] `.harness/.gitignore` excludes `.env.local`, `logs/*` (keeping `.gitkeep`), `.image-hash`.
- [ ] `.harness/.env.local.example` exists documenting `CLAUDE_CODE_OAUTH_TOKEN` and pointing at `claude setup-token`.
- [ ] Smoke test run: `pwsh ./.harness/run.ps1 -SmokeTest` on Windows and `./.harness/run.sh --smoke-test` on Linux both produce "PONG" in the terminal, write a complete log to `.harness/logs/smoke-test.log`, exit 0, and rebuild the image only on Dockerfile change.
- [ ] Pre-flight failures print specific error + remediation command (e.g., "Missing CLAUDE_CODE_OAUTH_TOKEN. Run: claude setup-token").

## Blocked by

None — can start immediately.
