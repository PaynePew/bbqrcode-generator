## Parent

PRD 0002 — Generic Docker Agent Harness ([#27](https://github.com/PaynePew/qr_code_generator/issues/27))

## What to build

Add the plan phase to the harness. The wrapper supports three new entry points: bare `run` (plan → confirm → exit on n), `-Plan` (plan only, exit with ranking), and `-Issue N` (skip plan, claim branch only — implement happens in Slice 3).

The plan phase enumerates open GitHub issues (filtered by `tracker.filter_label` if set), reads the in-progress branch list and open PRs as deconflict signals, and asks claude to rank candidates by file-overlap reasoning over issue bodies. Output is structured JSON in a `<plan>` tag that the wrapper parses and presents.

Concurrent terminals are supported: each terminal's plan phase sees the host's current in-progress state and excludes claimed work. Branch creation is the atomic claim (deferred to Slice 3 implement, but the plan phase tags branches it intends to create so a competing terminal can see the intent).

The heartbeat reducer ships in this slice because plan is the first phase to produce stream-json events the operator needs to see.

## Acceptance criteria

- [ ] `.harness/prompts/plan.md` is project-agnostic; references substituted via `{{KEY}}`: `{{TRACKER_LABEL_FLAG}}`, `{{BRANCH_PREFIX}}`, `{{IN_PROGRESS_LIST}}`, `{{ADR_FILENAMES}}`, `{{REPO}}`. Reads issue bodies + ADR filenames (titles only, no bodies).
- [ ] Plan prompt requires the agent to output `<plan>` JSON with `top` (id, title, branch, reason, ac_count), `alternatives` (id, title, branch, reason — short), `blocked` (id, blocked_by, title).
- [ ] `.harness/lib/scan-deconflict.{ps1,sh}` enumerates local branches matching `{prefix}-issue*-*` + open PRs from `gh pr list`, returns a set of issue numbers to exclude. Falls back to local-only if `gh` fails; skips malformed branch names without crashing. Same contract on both platforms.
- [ ] `.harness/lib/parse-plan.{ps1,sh}` extracts `<plan>...</plan>` JSON from claude stdout, validates required keys, returns typed struct OR a parse error. Handles: well-formed; multiple `<plan>` blocks (use last); malformed JSON; missing `top`; surrounding noise.
- [ ] `.harness/lib/heartbeat.{ps1,sh}` is a pure reducer: `reduce(state, stream_json_event) → new_state` updating `turns`, `elapsed_s`, `last_action`. Handles `system.init`, `assistant.text`, `tool_use`, `result` events plus unknown event types without crashing.
- [ ] Pester + bats tests for all three lib modules covering the stated cases.
- [ ] Wrapper flag set extends: `-Plan` (plan only, exit with ranking), `-Yes` (auto-confirm top candidate), `-Issue N` (skip plan, claim branch only — no implement yet).
- [ ] Bare command runs plan → renders top candidate + reason + alternatives → asks "Run #N? [Y/n]" → on `n`, exits clean with no branches created.
- [ ] Terminal renders header (issue/agent/model/branch/log) + single in-place updating heartbeat line via ANSI escapes; phase transition updates the `Agent:` header line; final exit replaces heartbeat with status line. Falls back to non-ANSI mode when virtual terminal not supported.
- [ ] Plan phase agent model defaults to Opus 4.7 with `max_turns: 10`. Configurable via `agents.plan.{model,max_turns}` in config (full agents block lands in Slice 6; minimal `model` + `max_turns` enough here).

## Blocked by

- #28 (Slice 1 — harness skeleton)
