#!/usr/bin/env bash
# render_prompt TEMPLATE [KEY=VALUE ...]
# Substitutes {{KEY}} placeholders; drops lines that resolve to empty.
render_prompt() {
    local template="$1"
    shift || true

    # Apply all KEY=VALUE substitutions
    local result="$template"
    for kv in "$@"; do
        local key="${kv%%=*}"
        local val="${kv#*=}"
        result="${result//\{\{$key\}\}/$val}"
    done

    # Process line-by-line: strip remaining {{...}}, drop blank lines
    local output=""
    while IFS= read -r line; do
        line=$(printf '%s' "$line" | sed 's/{{[A-Z_0-9]*}}//g')
        if [[ -n "${line// }" ]]; then
            output+="${line}"$'\n'
        fi
    done <<< "$result"

    printf '%s' "${output%$'\n'}"
}
