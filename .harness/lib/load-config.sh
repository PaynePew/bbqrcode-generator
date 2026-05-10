#!/usr/bin/env bash
# load_config CONFIG_PATH
# Parses a shallow two-level YAML config, validates required keys, applies defaults.
# Exports: HARNESS_IMAGE, HARNESS_BRANCH_PREFIX, HARNESS_TRACKER_TYPE,
#          HARNESS_TRACKER_REPO, HARNESS_DEFAULT_MODEL
load_config() {
    local config_path="$1"

    if [[ ! -f "$config_path" ]]; then
        echo "ERROR: Config file not found: $config_path" >&2
        return 1
    fi

    # Extract top-level scalar values
    HARNESS_IMAGE=$(awk -F': ' '/^image:/ { $1=""; gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print }' "$config_path")
    HARNESS_BRANCH_PREFIX=$(awk -F': ' '/^branch_prefix:/ { $1=""; gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print }' "$config_path")

    # Extract nested tracker keys
    HARNESS_TRACKER_TYPE=$(awk '/^tracker:/{p=1;next} p && /^[^ ]/{p=0} p && /^  type:/{gsub(/^[[:space:]]*type:[[:space:]]*/,""); gsub(/[[:space:]]*$/,""); print; exit}' "$config_path")
    HARNESS_TRACKER_REPO=$(awk '/^tracker:/{p=1;next} p && /^[^ ]/{p=0} p && /^  repo:/{gsub(/^[[:space:]]*repo:[[:space:]]*/,""); gsub(/[[:space:]]*$/,""); print; exit}' "$config_path")

    # Extract nested defaults
    HARNESS_DEFAULT_MODEL=$(awk '/^defaults:/{p=1;next} p && /^[^ ]/{p=0} p && /^  model:/{gsub(/^[[:space:]]*model:[[:space:]]*/,""); gsub(/[[:space:]]*$/,""); print; exit}' "$config_path")

    # Validate required keys
    if [[ -z "$HARNESS_IMAGE" ]]; then
        echo "ERROR: Missing required config key: image. Check .harness/config.yml." >&2
        return 1
    fi
    if [[ -z "$HARNESS_BRANCH_PREFIX" ]]; then
        echo "ERROR: Missing required config key: branch_prefix. Check .harness/config.yml." >&2
        return 1
    fi
    if [[ -z "$HARNESS_TRACKER_TYPE" ]]; then
        echo "ERROR: Missing required config key: tracker.type. Check .harness/config.yml." >&2
        return 1
    fi
    if [[ "$HARNESS_TRACKER_TYPE" != "github" ]]; then
        echo "ERROR: tracker.type must be 'github' (v1 only supports github). Got: $HARNESS_TRACKER_TYPE" >&2
        return 1
    fi

    # Apply defaults
    HARNESS_DEFAULT_MODEL="${HARNESS_DEFAULT_MODEL:-claude-sonnet-4-6}"

    export HARNESS_IMAGE HARNESS_BRANCH_PREFIX HARNESS_TRACKER_TYPE HARNESS_TRACKER_REPO HARNESS_DEFAULT_MODEL
}
