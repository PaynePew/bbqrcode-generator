#!/usr/bin/env bash
# Generic Docker agent harness entry point for Linux / macOS / CI.
#
# Usage:
#   ./.harness/run.sh --smoke-test
#   ./.harness/run.sh --issue 28
set -euo pipefail

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HARNESS_ROOT/.." && pwd)"

# shellcheck source=lib/load-config.sh
source "$HARNESS_ROOT/lib/load-config.sh"
# shellcheck source=lib/render-prompt.sh
source "$HARNESS_ROOT/lib/render-prompt.sh"
# shellcheck source=lib/image-cache.sh
source "$HARNESS_ROOT/lib/image-cache.sh"

# ── Helpers ────────────────────────────────────────────────────────────────────

fail() {
    echo "ERROR: $1" >&2
    [[ -n "${2:-}" ]] && echo "  Run: $2" >&2
    exit 1
}

step() { printf '\e[36m── %s \e[90m%s\e[0m\n' "$1" "$(printf '%.0s─' {1..40})"; }

# ── Args ───────────────────────────────────────────────────────────────────────

SMOKE_TEST=false
ISSUE_NUMBER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --smoke-test) SMOKE_TEST=true ;;
        --issue)      shift; ISSUE_NUMBER="$1" ;;
        *) fail "Unknown argument: $1. Use --smoke-test or --issue N." ;;
    esac
    shift
done

if ! $SMOKE_TEST && [[ -z "$ISSUE_NUMBER" ]]; then
    fail "Specify --smoke-test or --issue N."
fi

# ── Pre-flight checks ──────────────────────────────────────────────────────────

step 'Pre-flight checks'

# 1. CLAUDE_CODE_OAUTH_TOKEN
if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    ENV_FILE="$HARNESS_ROOT/.env.local"
    if [[ -f "$ENV_FILE" ]]; then
        # shellcheck disable=SC1090
        set -o allexport; source "$ENV_FILE"; set +o allexport
    fi
fi
[[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] && \
    fail "Missing CLAUDE_CODE_OAUTH_TOKEN." "claude setup-token"

# 2. Docker daemon
docker info >/dev/null 2>&1 || fail "Docker daemon not running. Start Docker and retry."

# 3. gh auth
gh auth status >/dev/null 2>&1 || fail "Not authenticated with GitHub CLI." "gh auth login"

# 4. git repo
[[ -d "$REPO_ROOT/.git" ]] || fail "Not inside a git repository."

echo "  All pre-flight checks passed."

# ── Load config ────────────────────────────────────────────────────────────────

step 'Loading config'
load_config "$HARNESS_ROOT/config.yml"
IMAGE_NAME="$HARNESS_IMAGE"
MARKER_PATH="$HARNESS_ROOT/.image-hash"
echo "  image=$IMAGE_NAME  branch_prefix=$HARNESS_BRANCH_PREFIX"

# ── Image cache check / rebuild ────────────────────────────────────────────────

step 'Image cache check'
if [[ "$(image_rebuild_needed "$HARNESS_ROOT/Dockerfile" "$MARKER_PATH")" == "true" ]]; then
    echo "  Rebuilding image: $IMAGE_NAME"
    docker build -t "$IMAGE_NAME" -f "$HARNESS_ROOT/Dockerfile" "$REPO_ROOT"
    save_image_hash "$HARNESS_ROOT/Dockerfile" "$MARKER_PATH"
    echo "  Image built and hash cached."
else
    echo "  Image up-to-date — no rebuild needed."
fi

# ── Select and render prompt ───────────────────────────────────────────────────

if $SMOKE_TEST; then
    PROMPT_FILE="$HARNESS_ROOT/prompts/smoke-test.md"
    LOG_FILE="$HARNESS_ROOT/logs/smoke-test.log"
    RUN_LABEL="smoke-test"
    RENDERED=$(render_prompt "$(cat "$PROMPT_FILE")")
else
    PROMPT_FILE="$HARNESS_ROOT/prompts/implement.md"
    LOG_FILE="$HARNESS_ROOT/logs/issue-${ISSUE_NUMBER}.log"
    RUN_LABEL="issue-${ISSUE_NUMBER}"
    RENDERED=$(render_prompt "$(cat "$PROMPT_FILE")" "ISSUE_NUMBER=$ISSUE_NUMBER")
fi

[[ -f "$PROMPT_FILE" ]] || fail "Prompt file not found: $PROMPT_FILE"

PROMPT_MOUNT="$HARNESS_ROOT/.current-prompt.md"
printf '%s\n' "$RENDERED" > "$PROMPT_MOUNT"

# ── Run container ──────────────────────────────────────────────────────────────

step "Running $RUN_LABEL"
echo "  Log → $LOG_FILE"
mkdir -p "$(dirname "$LOG_FILE")"

docker run --rm \
    --volume "${REPO_ROOT}:/workspace" \
    --env    "CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN" \
    --workdir /workspace \
    "$IMAGE_NAME" \
    bash -lc 'claude -p "$(cat /workspace/.harness/.current-prompt.md)"' \
    2>&1 | tee "$LOG_FILE"

EXIT_CODE="${PIPESTATUS[0]}"
rm -f "$PROMPT_MOUNT"

# ── Summary ────────────────────────────────────────────────────────────────────

if [[ "$EXIT_CODE" -eq 0 ]]; then
    STATUS="COMPLETE"
    COLOR='\e[32m'
else
    STATUS="FAILED (exit $EXIT_CODE)"
    COLOR='\e[31m'
fi

printf '\n'
printf "${COLOR}╔══════════════════════════════════════════════════╗\e[0m\n"
printf "${COLOR}║  %-46s  ║\e[0m\n" "$RUN_LABEL — $STATUS"
printf "${COLOR}╚══════════════════════════════════════════════════╝\e[0m\n"

[[ "$EXIT_CODE" -eq 0 && "$SMOKE_TEST" == "true" ]] && \
    echo "  Log saved to: $LOG_FILE"

exit "$EXIT_CODE"
