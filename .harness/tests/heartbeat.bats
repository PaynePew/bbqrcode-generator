#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../lib/heartbeat.sh"
    export HB_TURNS=0
    export HB_ELAPSED_S=0
    export HB_LAST_ACTION=""
}

@test "system.init resets state and sets last_action to init" {
    export HB_TURNS=5 HB_ELAPSED_S=10 HB_LAST_ACTION="tool:bash"
    heartbeat_reduce '{"type":"system.init"}'
    [ "$HB_TURNS" -eq 0 ]
    [ "$HB_ELAPSED_S" = "0" ]
    [ "$HB_LAST_ACTION" = "init" ]
}

@test "assistant.text increments turns" {
    export HB_TURNS=2
    heartbeat_reduce '{"type":"assistant.text","text":"hello"}'
    [ "$HB_TURNS" -eq 3 ]
}

@test "assistant.text sets last_action to thinking" {
    heartbeat_reduce '{"type":"assistant.text","text":"hello"}'
    [ "$HB_LAST_ACTION" = "thinking" ]
}

@test "tool_use sets last_action with tool name" {
    heartbeat_reduce '{"type":"tool_use","name":"bash"}'
    [ "$HB_LAST_ACTION" = "tool:bash" ]
}

@test "tool_use falls back to tool:tool when name is absent" {
    heartbeat_reduce '{"type":"tool_use"}'
    [ "$HB_LAST_ACTION" = "tool:tool" ]
}

@test "result updates elapsed_s" {
    heartbeat_reduce '{"type":"result","elapsed_s":42.5}'
    [ "$HB_ELAPSED_S" = "42.5" ]
}

@test "result sets last_action to done" {
    heartbeat_reduce '{"type":"result","elapsed_s":10}'
    [ "$HB_LAST_ACTION" = "done" ]
}

@test "unknown event leaves state unchanged" {
    export HB_TURNS=2 HB_ELAPSED_S=5 HB_LAST_ACTION="thinking"
    heartbeat_reduce '{"type":"future.unrecognised","data":"x"}'
    [ "$HB_TURNS" -eq 2 ]
    [ "$HB_ELAPSED_S" = "5" ]
    [ "$HB_LAST_ACTION" = "thinking" ]
}
