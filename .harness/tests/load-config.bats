#!/usr/bin/env bats

FIXTURES_DIR="$BATS_TEST_DIRNAME/fixtures"

setup() {
    source "$BATS_TEST_DIRNAME/../lib/load-config.sh"
}

@test "loads a valid config with required keys" {
    load_config "$FIXTURES_DIR/valid-config.yml"
    [ "$HARNESS_IMAGE" = "agent-harness:latest" ]
    [ "$HARNESS_BRANCH_PREFIX" = "kanban-issue" ]
    [ "$HARNESS_TRACKER_TYPE" = "github" ]
}

@test "applies default model when not specified" {
    load_config "$FIXTURES_DIR/minimal-config.yml"
    [ "$HARNESS_DEFAULT_MODEL" = "claude-sonnet-4-6" ]
}

@test "errors when image key is missing" {
    run load_config "$FIXTURES_DIR/missing-image.yml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"image"* ]]
}

@test "errors when branch_prefix key is missing" {
    run load_config "$FIXTURES_DIR/missing-branch-prefix.yml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"branch_prefix"* ]]
}

@test "errors when tracker.type is missing" {
    run load_config "$FIXTURES_DIR/missing-tracker-type.yml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"tracker.type"* ]]
}

@test "errors when tracker.type is not github" {
    run load_config "$FIXTURES_DIR/invalid-tracker-type.yml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"github"* ]]
}
