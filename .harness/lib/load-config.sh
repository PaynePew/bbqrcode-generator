#!/usr/bin/env bash
# load_config CONFIG_PATH
# Parses a shallow two-level YAML config, validates required keys, applies defaults.
# Exports: HARNESS_IMAGE, HARNESS_BRANCH_PREFIX, HARNESS_TRACKER_TYPE,
#          HARNESS_TRACKER_REPO, HARNESS_DEFAULT_MODEL

# _yaml_top FILE KEY → prints scalar value of a top-level YAML key, or empty.
_yaml_top() {
    local file="$1" key="$2"
    awk -v k="$key" '
        $0 ~ "^" k ":" {
            sub("^" k ":[[:space:]]*", "")
            sub(/[[:space:]]+$/, "")
            print; exit
        }
    ' "$file"
}

# _yaml_nested FILE PARENT CHILD → prints scalar value of PARENT.CHILD, or empty.
_yaml_nested() {
    local file="$1" parent="$2" child="$3"
    awk -v p="$parent" -v c="$child" '
        $0 ~ "^" p ":"      { in_p = 1; next }
        in_p && /^[^ ]/     { in_p = 0 }
        in_p && $0 ~ "^  " c ":" {
            sub("^[[:space:]]*" c ":[[:space:]]*", "")
            sub(/[[:space:]]+$/, "")
            print; exit
        }
    ' "$file"
}

load_config() {
    local config_path="$1"

    if [[ ! -f "$config_path" ]]; then
        echo "ERROR: Config file not found: $config_path" >&2
        return 1
    fi

    HARNESS_IMAGE=$(_yaml_top "$config_path" "image")
    HARNESS_BRANCH_PREFIX=$(_yaml_top "$config_path" "branch_prefix")
    HARNESS_TRACKER_TYPE=$(_yaml_nested "$config_path" "tracker" "type")
    HARNESS_TRACKER_REPO=$(_yaml_nested "$config_path" "tracker" "repo")
    HARNESS_DEFAULT_MODEL=$(_yaml_nested "$config_path" "defaults" "model")

    if [[ -z "$HARNESS_IMAGE" ]]; then
        echo "ERROR: Missing required config key 'image' in $config_path." >&2
        return 1
    fi
    if [[ -z "$HARNESS_BRANCH_PREFIX" ]]; then
        echo "ERROR: Missing required config key 'branch_prefix' in $config_path." >&2
        return 1
    fi
    if [[ -z "$HARNESS_TRACKER_TYPE" ]]; then
        echo "ERROR: Missing required config key 'tracker.type' in $config_path." >&2
        return 1
    fi
    if [[ "$HARNESS_TRACKER_TYPE" != "github" ]]; then
        echo "ERROR: tracker.type must be 'github' (v1 only supports github). Got: '$HARNESS_TRACKER_TYPE' in $config_path." >&2
        return 1
    fi

    HARNESS_DEFAULT_MODEL="${HARNESS_DEFAULT_MODEL:-claude-sonnet-4-6}"

    export HARNESS_IMAGE HARNESS_BRANCH_PREFIX HARNESS_TRACKER_TYPE HARNESS_TRACKER_REPO HARNESS_DEFAULT_MODEL
}
