# Issue Tracker

**Type:** bd (beads) — local-first issue tracker
**CLI:** `bd`
**Sync:** Dolt DB synced via `refs/dolt/data` on the git remote (NOT GitHub Issues). Run `bd prime` for full workflow.

> **Primary tracker is bd.** All new issues — including those created by the
> `to-issues` and `triage` skills — go into bd. GitHub Issues
> (`PaynePew/qr_code_generator`) is **legacy/historical only**: the pre-bd slices
> (#23–#26 etc.) live there for reference and are not actively maintained. Do not
> create new work in GitHub Issues. When migrating an old GitHub issue into bd,
> link it with `--external-ref gh-<number>`.

## How skills interact with issues

| Operation | Command |
|-----------|---------|
| Create | `bd create "title" -d "description" --acceptance "criteria" -l afk` |
| Batch create (from a plan) | `bd create -f slices.md` or `bd create --graph plan.json` (encodes deps) |
| List all | `bd list` |
| List claimable work | `bd ready` (open issues with no active blockers) |
| View | `bd show <id>` |
| Claim | `bd update <id> --claim` (or `bd ready --claim` to grab the first ready one) |
| Close | `bd close <id>` |
| Add dependency | `bd dep add <blocked-id> <blocker-id>` (blocked depends on blocker) |
| Inspect deps | `bd dep tree <id>` / `bd dep list <id>` |
| Add label | `bd label add <id> <label>` |

Labels do not need pre-registration (unlike `gh label create`) — they are created
on first use.

## How `to-issues` maps onto bd

The `to-issues` skill is tracker-agnostic; it publishes to "the issue tracker"
defined here, i.e. bd. Concrete mapping for step 5 (Publish):

- **Title** → `bd create "<title>"`
- **What to build** → `-d "<description>"` (or `--body-file -` for long bodies)
- **Acceptance criteria** → `--acceptance "<criteria>"`
- **Type (HITL / AFK)** → `-l hitl` or `-l afk`
- **Blocked by** → create blockers first, capture their `bd-xxx` ids, then create
  the dependent slice with `--deps 'blocked-by:bd-<blocker>'`, or wire afterwards
  with `bd dep add <blocked> <blocker>`. For a whole plan at once, prefer
  `bd create --graph plan.json` which creates all slices + dependencies atomically.
- **"ready-for-agent"** → native: an AFK slice with no open blockers is
  automatically surfaced by `bd ready`. The label is optional, not required.

Publish blockers before the slices that depend on them so real `bd-xxx`
identifiers can be referenced.

## Conventions

- Issues should have a clear title and a description of the problem or feature.
- Use dependencies (`bd dep`) to express ordering — `bd ready` then computes what
  is claimable. This replaces the GitHub "ready-for-agent" label gate.
- Labels track HITL/AFK and triage state (see `triage-labels.md`).
