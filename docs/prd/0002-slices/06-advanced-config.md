## Parent

PRD 0002 — Generic Docker Agent Harness ([#27](https://github.com/PaynePew/qr_code_generator/issues/27))

## What to build

Extend the harness's configuration surface so it accommodates real projects beyond the smoke-test minimum. Three concerns layer in:

1. **`when:` predicates** in `tests:` and `typecheck:` config entries — evaluated against the working directory. Omit `when:` for unconditional entries (so flat-layout projects with no subtree predicates Just Work).
2. **`agents:` config section** with full per-phase `model` + `max_turns`. CLI flags (`-PlanModel`, `-ImplementModel`, `-ReviewModel`, `-MergeModel`, `-PlanMaxTurns`, etc.) override config; config overrides built-in defaults.
3. **Lifecycle hooks** (`hooks/before-tests.sh` and `hooks/after-implement.sh`) — host-side, non-blocking, optional. Invoked with the repo root as `cwd` and `HARNESS_ISSUE`, `HARNESS_BRANCH`, `HARNESS_PHASE` env vars set.

Plus the `tracker.filter_label` config is wired into the plan phase (Slice 2 supports the schema but doesn't filter; this slice closes the loop).

## Acceptance criteria

- [ ] `lib/load-config.{ps1,sh}` extends: `when:` predicate evaluation against working directory (supports `exists(<path>)` predicate; `true` predicate; absent `when:` defaults to applied). Pester + bats tests cover each predicate variant + nested tests with mixed when/no-when.
- [ ] `agents:` config section fully implemented with per-phase `model` + `max_turns`. Tests cover: empty agents block (use defaults); partial agents block (one phase set, others default); full agents block.
- [ ] CLI flags `-PlanModel`, `-ImplementModel`, `-ReviewModel`, `-MergeModel` and `-PlanMaxTurns`/`-ImplementMaxTurns`/`-ReviewMaxTurns`/`-MergeMaxTurns` (bash equivalents `--plan-model` etc.) override config values for the run. Tests cover the precedence chain (CLI > config > default).
- [ ] `hooks/before-tests.sh` and `hooks/after-implement.sh` are optional scripts the wrapper invokes if present. Run on host (not in container) with cwd = repo root and `HARNESS_ISSUE`, `HARNESS_BRANCH`, `HARNESS_PHASE` env vars set. Non-zero exit logs a warning but does not block phase progression.
- [ ] `tracker.filter_label` in config is passed to the plan prompt's `gh issue list --label "{{TRACKER_FILTER_LABEL}}"` invocation. Empty/missing label means no filter (all open issues).
- [ ] Flat-layout validation: a `config.yml` for a project with only `main.py` at root (no `frontend/` / `backend/`) and `tests:` entries without `when:` predicates passes config validation; tests run unconditionally in implement.
- [ ] Same-model pre-flight warning (from Slice 4) extends to all phases — warn whenever any two phases share the same model.
- [ ] Demo: a fixture project with `before-tests.sh` and `after-implement.sh` triggers the hooks during a real pipeline run; `HARNESS_*` env vars are observable inside the hook (e.g., hook echoes them to a file the test inspects).

## Blocked by

- #28 (Slice 1 — harness skeleton)
