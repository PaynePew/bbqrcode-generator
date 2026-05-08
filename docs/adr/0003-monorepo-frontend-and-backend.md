# ADR 0003: Single repo, sibling `frontend/` and `backend/` packages

**Status:** Accepted

## Context

The project began as a Python-only codebase with all source files at the repository root. With a frontend SPA being added (see PRD #6), the source tree needs to accommodate two distinct stacks — Python/FastAPI on the server side, TypeScript/React on the client side — without one obscuring the other.

Three structural options exist:

1. **Separate repositories** — one repo per stack, linked by API contract only.
2. **Monorepo with workspaces tooling** — Nx, Turborepo, or pnpm workspaces orchestrating both packages.
3. **Plain monorepo with sibling folders** — two top-level directories, each self-contained, no orchestration layer.

A prior refactor (commit `c1b86c7`) already moved Python source into `backend/` and added an empty `frontend/` placeholder, signalling the intent.

## Decision

Keep both stacks in this repository, with sibling top-level packages:

```
qr_code_generator/
├── backend/        # FastAPI + SQLAlchemy + pytest
├── frontend/       # Vite + React + TypeScript + Vitest
├── docs/           # Shared: ADRs, CONTEXT.md, agent docs, PRDs
├── tests/          # Backend pytest suite (kept at root for backend imports)
└── …
```

**No workspace tooling.** Each package owns its own dependency manifest (`requirements.txt` / `package.json`), its own lockfile, its own test runner, its own build command. They communicate only via the HTTP API documented in `CONTEXT.md`.

The root-level `package.json` is reserved for repo-wide tooling (currently the sandcastle harness) and is **not** the frontend's manifest. The frontend's `package.json` lives at `frontend/package.json`.

## Consequences

- **Single source of truth for cross-cutting concerns.** ADRs, the domain glossary (`CONTEXT.md`), agent skill configs, and PRDs apply to both stacks and live once at the repo root. No drift between two `docs/` trees.
- **Atomic cross-stack PRs.** Changes that span both layers (e.g., a new API field plus its frontend consumer) ship in one PR with one diff, one review, one CI run.
- **Simpler CI mental model.** Two independent jobs (`backend-tests`, `frontend-tests`) run in parallel against the same checkout. No workspace resolver, no inter-package symlinks.
- **No dependency sharing between stacks.** Because they are different language ecosystems, this is a non-issue — there is nothing to share.
- **The `tests/` directory at the root remains backend-only** for now (matches the existing pytest layout). The frontend test suite lives under `frontend/src/**/*.test.ts` per Vitest convention. Two test homes are acceptable.
- **Future split is reversible.** Each package is self-contained, so extracting `frontend/` to its own repo later is mechanical (`git filter-repo` + new origin) if a real reason emerges (separate deploy cadence, separate ownership, security boundaries).
- **No workspace tooling means no dependency hoisting, no shared `node_modules`.** Acceptable: there is exactly one `package.json` that needs `node_modules` (the frontend), so hoisting saves nothing.
