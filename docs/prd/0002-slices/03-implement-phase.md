## Parent

PRD 0002 — Generic Docker Agent Harness ([#27](https://github.com/PaynePew/qr_code_generator/issues/27))

## What to build

Add the implement phase. The wrapper's main flow becomes plan → confirm → implement (or with `-Issue N`, skip directly to implement). Implement creates the branch as the atomic claim (`git checkout -b {prefix}-issue{N}-{slug}` — if it fails because the branch exists and `-Resume` was not passed, fail clean with "already claimed"). It then runs the implement agent against the issue, eager-loading the issue body and parent PRD; CONTEXT.md and ADR bodies are read lazily.

Every implement run, on COMPLETE or BLOCKED, posts a structured comment to the issue: branch + status + commits + What-was-built + AC self-report + concerns. The agent never edits the issue body. Resume is explicit: `-Issue N -Resume` skips plan and continues on the existing branch, with dirty-tree handling baked into the prompt (stash or WIP commit, never `reset --hard` silently).

Rate-limit failures are detected by the wrapper grepping the run's log for `Rate limit exceeded` or `usage_limit_exceeded` substrings; the final summary surfaces an exact resume command.

## Acceptance criteria

- [ ] `.harness/prompts/implement.md` is project-agnostic; substitutions: `{{ISSUE}}`, `{{BRANCH}}`, `{{DOCS_PRD_DIR}}`, `{{DOCS_CONTEXT}}`, `{{DOCS_ADR_DIR}}`, `{{TESTS_BLOCK}}`, `{{TYPECHECK_BLOCK}}`, `{{COMMIT_STYLE}}`. Missing-doc paths drop their prompt lines cleanly via render-prompt.
- [ ] Implement prompt instructs eager-load of issue body + parent PRD (if referenced) only; CONTEXT.md and ADR bodies read lazily on demand.
- [ ] Branch creation is the atomic claim. First action on entering implement is `git checkout -b {branch}`; if the branch already exists and `-Resume` was not passed, the wrapper exits with "Branch already claimed by another terminal. To continue this work, re-run with -Resume."
- [ ] Implement prompt's dirty-tree-on-resume contract: on resume, if working tree has uncommitted changes, agent runs `git status`, either WIP-commits the changes or `git stash`es them with a summary line, never `git reset --hard` silently.
- [ ] Every implement run (COMPLETE or BLOCKED) posts a structured comment via `gh issue comment {{ISSUE}} --body-file -` with: branch name, status (COMPLETE / BLOCKED — one-line reason), commit list with subjects, "What was built" bullets grounded in files, AC self-report (mirroring the issue's checklist with `[x]`/`[ ]` and per-AC evidence), notes/concerns. Agent never edits the issue body.
- [ ] Wrapper flag set extends: `-Issue N` (skip plan, run implement on N), `-Resume` (resume on existing `{prefix}-issue{N}-*` branch — fails if no matching branch).
- [ ] Rate-limit detection: wrapper greps the run's log file for `Rate limit exceeded` or `usage_limit_exceeded`; final summary on non-zero exit prints "Rate limit hit. Resume with: pwsh ./.harness/run.ps1 -Issue {N} -Resume" when matched.
- [ ] Implement agent defaults to Sonnet 4.6 with `max_turns: 80`. Configurable via `agents.implement.{model,max_turns}`.
- [ ] Demo: `run -Issue {a real slice issue}` produces commits on a `kanban-issue{N}-*` branch and an end-of-run comment matching the structure above. Killing the process mid-implement and re-running with `-Issue {N} -Resume` continues from the existing commits without re-scaffolding.

## Blocked by

- #29 (Slice 2 — plan phase)
