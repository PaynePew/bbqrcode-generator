#Requires -Version 7
# Pure reducer: reduce(state, stream_json_event) → new_state
# No I/O, no side effects.

function Invoke-HeartbeatReduce {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][hashtable]$Event
    )

    $new = @{
        turns       = $State.turns
        elapsed_s   = $State.elapsed_s
        last_action = $State.last_action
    }

    switch ($Event.type) {
        'system.init' {
            $new.turns       = 0
            $new.elapsed_s   = 0
            $new.last_action = 'init'
        }
        'assistant.text' {
            $new.turns       = $State.turns + 1
            $new.last_action = 'thinking'
        }
        'tool_use' {
            $toolName        = if ($Event.ContainsKey('name') -and $Event.name) { $Event.name } else { 'tool' }
            $new.last_action = "tool:$toolName"
        }
        'result' {
            if ($Event.ContainsKey('elapsed_s') -and $null -ne $Event.elapsed_s) {
                $new.elapsed_s = $Event.elapsed_s
            }
            $new.last_action = 'done'
        }
        default {
            # Unknown event — pass through unchanged
        }
    }

    return $new
}
