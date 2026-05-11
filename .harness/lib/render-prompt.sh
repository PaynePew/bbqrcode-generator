#!/usr/bin/env bash
# render_prompt TEMPLATE [KEY=VALUE ...]
# Substitutes {{KEY}} placeholders; drops lines that resolve to whitespace-only.
render_prompt() {
    local template="$1"
    shift || true

    # Apply all KEY=VALUE substitutions (parameter expansion is literal, not regex).
    local result="$template"
    for kv in "$@"; do
        local key="${kv%%=*}"
        local val="${kv#*=}"
        result="${result//\{\{$key\}\}/$val}"
    done

    local output=""
    while IFS= read -r line; do
        # Strip any remaining {{KEY}} placeholders (unmapped keys → empty).
        line=$(printf '%s' "$line" | sed 's/{{[A-Z_0-9]*}}//g')
        # Match PS .Trim(): drop if line has no non-whitespace characters.
        if [[ "$line" =~ [^[:space:]] ]]; then
            output+="${line}"$'\n'
        fi
    done <<< "$result"

    printf '%s' "${output%$'\n'}"
}
