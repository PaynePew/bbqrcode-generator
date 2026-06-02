# Triage Labels

These labels are used by the `triage` skill to move issues through the triage
state machine. The tracker is **bd** (see `issue-tracker.md`).

| Role | Label string | Meaning |
|------|-------------|---------|
| Needs evaluation | `needs-triage` | Maintainer needs to evaluate this issue |
| Waiting on reporter | `needs-info` | Blocked — need more info from the submitter |
| AFK-agent-ready | `ready-for-agent` | Fully specified; an agent can pick it up with no human context |
| Human-ready | `ready-for-human` | Needs a human to implement |
| Won't action | `wontfix` | Will not be addressed |

## Applying labels in bd

No setup step is required — bd creates labels on first use. Apply with:

```bash
bd label add <id> needs-triage      # tag for evaluation
bd label add <id> ready-for-agent   # mark AFK-ready
bd label remove <id> needs-triage   # clear when state changes
bd label list-all                   # see every label in use
```

## Note on `ready-for-agent` vs `bd ready`

bd has **native** readiness: `bd ready` lists open issues with no active blockers,
so claimable AFK work surfaces automatically from the dependency graph. The
`ready-for-agent` label is therefore largely redundant and optional — prefer
expressing "can start now" as *no open blockers* (`bd dep`) rather than a label.
Keep the label only if you want an explicit human-applied signal distinct from
dependency state. The other labels (`needs-triage`, `needs-info`,
`ready-for-human`, `wontfix`) remain useful since bd has no native equivalent.
