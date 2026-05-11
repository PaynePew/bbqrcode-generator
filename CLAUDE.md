## Agent skills

### Issue tracker

Issues live in GitHub Issues (`PaynePew/qr_code_generator`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — `CONTEXT.md` and `docs/adr/` at repo root. See `docs/agents/domain.md`.

## Planning Document Rule

When writing `prompts/plan.md`, `prompts/implement.md`, `prompts/review.md`, or `prompts/merge.md`, delegate to an Agent sub-task with `model="opus"` instead of writing directly. After the agent completes, resume with the current model.

## Frontend Development Workflow

- Use the loaded `frontend-skill` to ensure best practices for React, Tailwind and UI design.
