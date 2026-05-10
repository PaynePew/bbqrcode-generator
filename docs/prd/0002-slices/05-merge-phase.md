## Parent

PRD 0002 — Generic Docker Agent Harness ([#27](https://github.com/PaynePew/qr_code_generator/issues/27))

## What to build

Add the merge phase. After review, the wrapper runs the merge agent in a fresh container. Merge verifies tests pass on the branch, pushes the branch to origin, opens a PR with `gh pr create --fill`, and comments on the issue with the PR link. The PR body includes `Closes #N`, a commit summary, the AC self-report, and reviewer notes.

The merge phase never `git merge`s to main, never `gh issue close`s, never sets up `--auto-merge`. GitHub closes the issue when the human merges the PR via the `Closes #N` keyword. Adds `-SkipMerge` flag to stop after review and leave the commits local.

The final summary box renders the full pipeline result: per-phase status, branch, PR URL, next-step command.

## Acceptance criteria

- [ ] `.harness/prompts/merge.md` is project-agnostic; substitutions: `{{BRANCH}}`, `{{ISSUE}}`, `{{REPO}}`, `{{TESTS_BLOCK}}`. The prompt's job: (1) verify branch is clean and tests pass; (2) `git push -u origin {{BRANCH}}`; (3) `gh pr create --fill --body "..."` with body containing `Closes #{{ISSUE}}`, commit summary, AC self-report, reviewer notes; (4) comment on the issue: "PR #X opened, ready for human review."
- [ ] Merge agent does NOT: `git merge` to main, `git checkout main`, `gh issue close`, set `--auto-merge`, squash, or rebase. The prompt explicitly forbids these.
- [ ] Wrapper flag set extends: `-SkipMerge` / `--skip-merge` (commits and review stay on the branch, no push, no PR).
- [ ] Final summary box always prints at end of run (success or failure). Success format: header line, per-phase status (`✓ COMPLETE` / `✗ <reason>` / `⊝ SKIPPED`), branch name, log path, PR URL if applicable, next-step command. Failure format: includes the specific phase that failed and the resume command.
- [ ] Merge agent defaults to Sonnet 4.6 with `max_turns: 20`. Configurable via `agents.merge.{model,max_turns}`.
- [ ] Demo: full pipeline `run` (or `run -Issue N`) on a real slice from `plan → implement → review → merge` ends with a PR opened against `main` containing `Closes #N`. The issue receives an implementer comment, a reviewer comment, and a "PR #X opened" comment. `main` is untouched. The issue stays open until the human merges the PR.

## Blocked by

- #31 (Slice 4 — review phase)
