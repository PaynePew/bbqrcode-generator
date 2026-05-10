## Parent

PRD 0002 — Generic Docker Agent Harness ([#27](https://github.com/PaynePew/qr_code_generator/issues/27))

## What to build

The wrap-up slice. Two production-readiness deliverables and one cleanup:

1. **CI matrix** — a GitHub Actions workflow that runs Pester on `windows-latest` and bats-core on `ubuntu-latest`, triggered on PRs touching `.harness/`. This enforces the PS+Bash parity discipline mechanically rather than relying on operator memory.
2. **Operator README** — replaces the existing `.harness/README.md` with the full operator manual: prerequisites, `claude setup-token`, the flag reference, troubleshooting, the four-phase pipeline diagram, the cost/rate-limit reality section.
3. **Retire legacy** — delete `.sandcastle/` and the old `.harness/{run-issue,run-hello}.ps1`, `.harness/prompts/{implement,review}.md`, `.harness/CODING_STANDARDS.md` (replaced by the project-specific overlay in the new location). HITL because the retirement decision benefits from a human read-through of the README before publication.

## Acceptance criteria

- [ ] `.github/workflows/agent-harness.yml` exists and runs on PRs touching `.harness/` paths. Matrix: `windows-latest` runs Pester suite from `.harness/tests/*.Tests.ps1`; `ubuntu-latest` runs bats-core suite from `.harness/tests/*.bats`. Both must pass for the workflow to succeed.
- [ ] Bats-core is installed in CI either via package manager (`apt-get install bats`), git submodule, or download from upstream. Pester is installed via PowerShell module install.
- [ ] `.harness/README.md` is replaced with the operator manual covering: prerequisites (Docker, gh, claude CLI, `claude setup-token`); first run; bare `run` flow; flag reference table; manual issue selection from another terminal; resume after rate-limit; troubleshooting (pre-flight failures, hooks not firing, log file location); the four-phase pipeline diagram with `claude run` boundaries; cost reality under subscription auth.
- [ ] README references PRD #27 and ADR 0008 as the source of truth for design decisions.
- [ ] Legacy `.sandcastle/` directory removed (entire directory).
- [ ] Legacy `.harness/run-issue.ps1`, `.harness/run-hello.ps1`, `.harness/prompts/implement.md`, `.harness/prompts/review.md`, `.harness/CODING_STANDARDS.md` removed. (`.harness/Dockerfile` may or may not change — if Slice 1's Dockerfile supersedes it, this issue removes the old one; otherwise no change here.)
- [ ] `.harness/feature.md` (the pointer doc) is removed since the PRD and ADR are now the canonical entry points and the harness directory itself is the implementation.
- [ ] HITL gate: before retiring `.sandcastle/`, the human merging this PR confirms via PR comment that the new harness has been validated against at least one real slice end-to-end (plan → merge to PR).

## Blocked by

- #28 (Slice 1 — harness skeleton)
- #29 (Slice 2 — plan phase)
- #30 (Slice 3 — implement phase)
- #31 (Slice 4 — review phase)
- #32 (Slice 5 — merge phase)
- #33 (Slice 6 — advanced config)
