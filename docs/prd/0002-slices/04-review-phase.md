## Parent

PRD 0002 — Generic Docker Agent Harness ([#27](https://github.com/PaynePew/qr_code_generator/issues/27))

## What to build

Add the review phase. After implement, the wrapper runs a fresh `docker run --rm` for review on the same branch. Review reads diff + commit log + CONTEXT.md + ADR filenames + the layered review rubric (universal rules baked into the prompt + per-project `.harness/CODING_STANDARDS.md` overlay substituted via `{{CODING_STANDARDS_BLOCK}}`).

Review never changes WHAT the code does — only HOW. It produces `refactor:` commits or no commits, and posts a structured comment on the issue covering: changes made, concerns flagged for human, test results, standards drift. Adds `-SkipReview` flag to bypass.

Self-review safety is enforced by three layers, all structural: different default models (Sonnet implement / Opus review), different prompts (doer vs critic), and the fresh-container-per-phase contract (reviewer has zero memory of implementer's reasoning trace).

## Acceptance criteria

- [ ] `.harness/prompts/review.md` is project-agnostic; substitutions: `{{BRANCH}}`, `{{TARGET_BRANCH}}`, `{{DOCS_CONTEXT}}`, `{{DOCS_ADR_DIR}}`, `{{CODING_STANDARDS_BLOCK}}`.
- [ ] Review prompt has a universal review rubric baked in: no `as any` / `@ts-ignore`, no swallowed errors, no nested ternaries, no over-clever one-liners, no paraphrasing comments. Layered after with `{{CODING_STANDARDS_BLOCK}}` substituted from `.harness/CODING_STANDARDS.md` if it exists, empty string otherwise.
- [ ] Review prompt enforces: correctness first (matching AC, edge cases, unsafe casts, secrets), then clarity; preserves functionality (never changes WHAT, only HOW); refactor commits use `refactor:` prefix; runs tests + typecheck after each meaningful change.
- [ ] Review run posts a structured comment via `gh issue comment` covering: Changes made (list of refactor commits, or "none"); Concerns flagged for human (correctness or scope issues not safely fixed); Test results; Standards drift (rules violated but not fixed). Agent never edits the issue body.
- [ ] Wrapper flag set extends: `-SkipReview` / `--skip-review` (omit review phase, still allow merge).
- [ ] Same-model pre-flight warning: if `agents.implement.model` equals `agents.review.model`, wrapper prints a warning explaining the loss of cross-model self-review safety but proceeds without blocking.
- [ ] Fresh container per phase: review runs in a separate `docker run --rm` from implement. Verified by either container-ID assertion or by counting `docker run` invocations per pipeline (must be ≥2 when review enabled).
- [ ] Review agent defaults to Opus 4.7 with `max_turns: 30`. Configurable via `agents.review.{model,max_turns}`.
- [ ] Demo: end-to-end run on a slice issue produces commits via implement, then `refactor:` commits (or "no changes needed") via review, plus a structured review comment on the issue.

## Blocked by

- #30 (Slice 3 — implement phase)
