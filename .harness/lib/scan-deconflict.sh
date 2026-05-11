#!/usr/bin/env bash
# scan_deconflict BRANCH_PREFIX [PR_JSON]
# Outputs newline-separated issue numbers claimed by in-progress branches or open PRs.
# Falls back to local-only if gh fails or PR_JSON arg is omitted.
# Silently skips malformed branch names.
#
# Branch naming convention: {prefix}{N}-{description}, e.g. kanban-issue42-my-feature
#
# Testing: set SCAN_MOCK_BRANCHES to a newline-delimited branch list to skip git branch.

scan_deconflict() {
    local prefix="$1"
    local have_pr_arg="${2+set}"
    local pr_json="${2:-}"

    # ── Local branches ────────────────────────────────────────────────────────
    local branches_raw
    if [[ -n "${SCAN_MOCK_BRANCHES+x}" ]]; then
        branches_raw="$SCAN_MOCK_BRANCHES"
    else
        branches_raw=$(git branch 2>/dev/null || true)
    fi

    local branch
    while IFS= read -r branch; do
        branch="${branch#\* }"  # strip "* " current-branch marker
        branch="${branch# }"    # strip leading space
        if [[ "$branch" =~ ^${prefix}([0-9]+)- ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
        # Malformed / non-matching names silently skipped
    done <<< "$branches_raw"

    # ── Open PRs ──────────────────────────────────────────────────────────────
    if [[ "$have_pr_arg" != "set" ]]; then
        pr_json=$(gh pr list --state open --json number,headRefName 2>/dev/null || true)
    fi

    if [[ -n "$pr_json" ]]; then
        local ref
        while IFS= read -r ref; do
            if [[ "$ref" =~ ^${prefix}([0-9]+)- ]]; then
                echo "${BASH_REMATCH[1]}"
            fi
        done < <(printf '%s' "$pr_json" | grep -o '"headRefName":"[^"]*"' | sed 's/"headRefName":"//;s/"//')
    fi
}
