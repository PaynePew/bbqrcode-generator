# TASK

Review the code changes on branch `{{BRANCH}}` (target: `{{TARGET_BRANCH}}`) for issue **#{{ISSUE}}** and improve clarity, consistency, and maintainability **while preserving exact functionality**.

# CONTEXT

## Branch diff

```bash
git checkout {{BRANCH}}
git diff {{TARGET_BRANCH}}...{{BRANCH}}
```

## Commits on this branch

```bash
git log {{TARGET_BRANCH}}..{{BRANCH}} --oneline
```

## Issue intent

```bash
gh issue view {{ISSUE}}
```

## Domain references (load lazily, only when relevant)

- Domain glossary: `{{DOCS_CONTEXT}}` — flag drift from canonical terms
- ADR directory: `{{DOCS_ADR_DIR}}` — flag any change that contradicts a recorded decision

# REVIEW PROCESS

1. **Understand the change.** Read the diff and commit messages. What is the implementer solving? What does the issue's AC require?

2. **Check correctness first** (cheaper to fix than to refactor on top of a bug):
   - Does the implementation match the AC and PRD intent?
   - Are edge cases handled (empty inputs, error responses, network failures)?
   - Are new/changed behaviors covered by tests?
   - Any unsafe casts (`as any`, `// @ts-ignore`, `# type: ignore`) without inline justification?
   - Any unchecked nulls or swallowed errors?
   - Any injection risk, credential leakage, or hardcoded secrets?

3. **Then look for clarity wins**:
   - Unnecessary complexity, deep nesting, redundant abstractions
   - Names that don't match what the thing does
   - Comments that paraphrase obvious code (delete) — keep only WHY-comments
   - Nested ternaries — prefer `if/else` chains
   - Over-clever one-liners — prefer explicit code

4. **Maintain balance.** Do not:
   - Over-simplify to obscurity
   - Combine too many concerns into one function
   - Remove helpful abstractions
   - Refactor speculatively — only fix what is wrong now

5. **Apply project standards** (substituted from `.harness/CODING_STANDARDS.md` — copied per-project from the bundled `.example` template — if present; otherwise empty):

{{CODING_STANDARDS_BLOCK}}

6. **Preserve functionality.** Never change WHAT the code does — only HOW. All original outputs and behaviors must remain intact. If a behavior change is needed, flag it for the human and do NOT make the change yourself.

# EXECUTION

If you find improvements to make:

1. Make changes directly on `{{BRANCH}}`.
2. Run tests + typecheck after each meaningful change.
3. Commit with `refactor:` prefix and a clear message. One logical change per commit.

If the code is already clean and well-structured, do nothing.

# COMPLETION

When done, post a structured review comment then exit:

```bash
gh issue comment {{ISSUE}} --body-file - <<'EOF'
## Review report

**Branch:** {{BRANCH}}
**Status:** COMPLETE

### Changes made
<!-- list of refactor commits, or "none" -->

### Concerns flagged for human
<!-- correctness or scope issues not safely fixed by this agent -->

### Test results
<!-- pass/fail counts -->

### Standards drift
<!-- rules violated but not fixed, with file:line references -->
EOF
```

Output `<promise>COMPLETE</promise>` and exit.

# HARD RULES

- Do NOT push, do NOT modify `{{TARGET_BRANCH}}`, do NOT close the issue, do NOT touch `.harness/`, `.sandcastle/`, `.claude/`.
- Do NOT introduce new features or expand scope. Flag anything missing for the human.
- Do NOT rewrite history (`git rebase`, `git commit --amend` are forbidden). Add new commits only.
