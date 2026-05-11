#!/usr/bin/env bash
# heartbeat_reduce EVENT_JSON
# Pure reducer operating on env-var state: HB_TURNS, HB_ELAPSED_S, HB_LAST_ACTION.
# Reads the current values, updates them in-place based on event type.
# Unknown events leave state unchanged. No I/O side effects.
#
# Usage:
#   export HB_TURNS=0 HB_ELAPSED_S=0 HB_LAST_ACTION=""
#   heartbeat_reduce '{"type":"system.init"}'

heartbeat_reduce() {
    local event_json="$1"

    # Extract event type (no jq dependency — simple grep/sed).
    local event_type
    event_type=$(printf '%s' "$event_json" | grep -o '"type":"[^"]*"' | head -1 | sed 's/"type":"//;s/"//')

    case "$event_type" in
        system.init)
            HB_TURNS=0
            HB_ELAPSED_S=0
            HB_LAST_ACTION="init"
            ;;
        assistant.text)
            HB_TURNS=$(( ${HB_TURNS:-0} + 1 ))
            HB_LAST_ACTION="thinking"
            ;;
        tool_use)
            local tool_name
            tool_name=$(printf '%s' "$event_json" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"//')
            HB_LAST_ACTION="tool:${tool_name:-tool}"
            ;;
        result)
            local elapsed
            elapsed=$(printf '%s' "$event_json" | grep -o '"elapsed_s":[0-9.]*' | head -1 | sed 's/"elapsed_s"://')
            if [[ -n "$elapsed" ]]; then
                HB_ELAPSED_S="$elapsed"
            fi
            HB_LAST_ACTION="done"
            ;;
        *)
            # Unknown event — pass through unchanged
            ;;
    esac

    export HB_TURNS HB_ELAPSED_S HB_LAST_ACTION
}
