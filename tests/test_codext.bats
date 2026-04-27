#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
    SCRIPT_PATH="$BATS_TEST_DIRNAME/../codext.sh"
    export TESTING="true"
}

# -------------------------------------------------------------
# Sanity & metadata
# -------------------------------------------------------------

@test "script has valid bash syntax" {
    run bash -n "$SCRIPT_PATH"
    assert_success
}

@test "show_help displays help message" {
    source "$SCRIPT_PATH"
    export -f show_help
    run show_help
    assert_output --partial "Codext - Codex, in a Loopt. Run OpenAI Codex CLI iteratively"
    assert_output --partial "USAGE:"
}

@test "show_version displays version" {
    source "$SCRIPT_PATH"
    export -f show_version
    run show_version
    assert_output --partial "codext version"
}

@test "show_help mentions max-tokens not max-cost" {
    source "$SCRIPT_PATH"
    export -f show_help
    run show_help
    assert_output --partial "--max-tokens"
    refute_output --partial "--max-cost"
}

# -------------------------------------------------------------
# Argument parsing
# -------------------------------------------------------------

@test "parse_arguments handles required flags" {
    source "$SCRIPT_PATH"
    parse_arguments -p "test prompt" -m 5 --owner user --repo repo

    assert_equal "$PROMPT" "test prompt"
    assert_equal "$MAX_RUNS" "5"
    assert_equal "$GITHUB_OWNER" "user"
    assert_equal "$GITHUB_REPO" "repo"
}

@test "parse_arguments handles dry-run flag" {
    source "$SCRIPT_PATH"
    parse_arguments -p "test" --dry-run
    assert_equal "$DRY_RUN" "true"
}

@test "parse_arguments handles auto-update flag" {
    source "$SCRIPT_PATH"
    AUTO_UPDATE="false"
    parse_arguments --auto-update
    assert_equal "$AUTO_UPDATE" "true"
}

@test "parse_arguments handles disable-updates flag" {
    source "$SCRIPT_PATH"
    DISABLE_UPDATES="false"
    parse_arguments --disable-updates
    assert_equal "$DISABLE_UPDATES" "true"
}

@test "parse_arguments handles max-tokens flag" {
    source "$SCRIPT_PATH"
    parse_arguments --max-tokens 1000000
    assert_equal "$MAX_TOKENS" "1000000"
}

@test "parse_arguments forwards unknown flag to EXTRA_CODEX_FLAGS" {
    source "$SCRIPT_PATH"
    EXTRA_CODEX_FLAGS=()
    parse_arguments --model gpt-5.5 --yolo
    assert_equal "${EXTRA_CODEX_FLAGS[0]}" "--model"
    assert_equal "${EXTRA_CODEX_FLAGS[1]}" "gpt-5.5"
    assert_equal "${EXTRA_CODEX_FLAGS[2]}" "--yolo"
}

@test "parse_arguments handles --effort flag" {
    source "$SCRIPT_PATH"
    parse_arguments --effort high
    assert_equal "$EFFORT" "high"
}

@test "parse_arguments expands --effort into a -c override" {
    source "$SCRIPT_PATH"
    EXTRA_CODEX_FLAGS=()
    EFFORT=""
    parse_arguments --effort medium
    # The two final entries should be the -c override appended after parsing.
    local n="${#EXTRA_CODEX_FLAGS[@]}"
    assert_equal "${EXTRA_CODEX_FLAGS[$((n-2))]}" "-c"
    assert_equal "${EXTRA_CODEX_FLAGS[$((n-1))]}" "model_reasoning_effort=medium"
}

@test "parse_arguments handles --fast flag" {
    source "$SCRIPT_PATH"
    FAST_MODE=false
    parse_arguments --fast
    assert_equal "$FAST_MODE" "true"
}

@test "parse_arguments expands --fast into a -c service_tier override" {
    source "$SCRIPT_PATH"
    EXTRA_CODEX_FLAGS=()
    FAST_MODE=false
    parse_arguments --fast
    local n="${#EXTRA_CODEX_FLAGS[@]}"
    assert_equal "${EXTRA_CODEX_FLAGS[$((n-2))]}" "-c"
    assert_equal "${EXTRA_CODEX_FLAGS[$((n-1))]}" "service_tier=fast"
}

@test "parse_arguments combines --effort and --fast" {
    source "$SCRIPT_PATH"
    EXTRA_CODEX_FLAGS=()
    EFFORT=""
    FAST_MODE=false
    parse_arguments --effort xhigh --fast
    assert_equal "$EFFORT" "xhigh"
    assert_equal "$FAST_MODE" "true"
    # Both -c overrides should be present in EXTRA_CODEX_FLAGS.
    local joined=" ${EXTRA_CODEX_FLAGS[*]} "
    [[ "$joined" == *" -c model_reasoning_effort=xhigh "* ]]
    [[ "$joined" == *" -c service_tier=fast "* ]]
}

@test "validate_arguments rejects invalid --effort value" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS="5"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    EFFORT="bogus"
    run validate_arguments
    assert_failure
    assert_output --partial "--effort must be one of"
}

@test "validate_arguments accepts every documented --effort value" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS="5"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    for level in minimal low medium high xhigh; do
        EFFORT="$level"
        run validate_arguments
        assert_success
    done
}

# -------------------------------------------------------------
# Argument validation
# -------------------------------------------------------------

@test "validate_arguments fails without prompt" {
    source "$SCRIPT_PATH"
    PROMPT=""
    run validate_arguments
    assert_failure
    assert_output --partial "Error: Prompt is required"
}

@test "validate_arguments fails without max-runs, max-tokens, or max-duration" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS=""
    MAX_TOKENS=""
    MAX_DURATION=""
    run validate_arguments
    assert_failure
    assert_output --partial "Error: Either --max-runs, --max-tokens, or --max-duration is required"
}

@test "validate_arguments passes with valid arguments" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS="5"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    run validate_arguments
    assert_success
}

@test "validate_arguments fails with non-positive max-tokens" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS=""
    MAX_DURATION=""
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"

    MAX_TOKENS="0"
    run validate_arguments
    assert_failure
    assert_output --partial "must be a positive integer"

    MAX_TOKENS="-100"
    run validate_arguments
    assert_failure

    MAX_TOKENS="abc"
    run validate_arguments
    assert_failure
}

@test "validate_arguments accepts valid max-tokens" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS=""
    MAX_DURATION=""
    MAX_TOKENS="1000000"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    run validate_arguments
    assert_success
}

@test "validate_arguments accepts max-duration" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS=""
    MAX_TOKENS=""
    MAX_DURATION="2h"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    validate_arguments
    assert_equal "$MAX_DURATION" "7200"
}

@test "validate_arguments fails with invalid max-duration format" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS=""
    MAX_TOKENS=""
    MAX_DURATION="invalid"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    run validate_arguments
    assert_failure
    assert_output --partial "Error: --max-duration must be a valid duration"
}

# -------------------------------------------------------------
# Requirements validation
# -------------------------------------------------------------

@test "validate_requirements fails when codex is missing" {
    function command() {
        if [ "$2" == "codex" ]; then
            return 1
        fi
        return 0
    }
    export -f command

    source "$SCRIPT_PATH"
    run validate_requirements

    assert_failure
    assert_output --partial "Error: Codex CLI is not installed"
}

@test "validate_requirements fails when jq is missing" {
    function command() {
        if [ "$2" == "jq" ]; then
            return 1
        fi
        return 0
    }
    function codex() { return 0; }
    export -f command codex

    source "$SCRIPT_PATH"
    run validate_requirements

    assert_failure
    assert_output --partial "jq is required for JSON parsing"
}

@test "validate_requirements fails when gh is missing and commits enabled" {
    function command() {
        if [ "$2" == "gh" ]; then
            return 1
        fi
        return 0
    }
    export -f command

    source "$SCRIPT_PATH"
    ENABLE_COMMITS="true"
    run validate_requirements

    assert_failure
    assert_output --partial "Error: GitHub CLI (gh) is not installed"
}

@test "validate_requirements passes when gh is missing but commits disabled" {
    function command() {
        if [ "$2" == "gh" ]; then
            return 1
        fi
        return 0
    }
    export -f command

    source "$SCRIPT_PATH"
    ENABLE_COMMITS="false"
    run validate_requirements

    assert_success
}

# -------------------------------------------------------------
# Iteration display
# -------------------------------------------------------------

@test "get_iteration_display formats with max runs" {
    source "$SCRIPT_PATH"
    run get_iteration_display 1 5 0
    assert_output "(1/5)"

    run get_iteration_display 2 5 1
    assert_output "(2/6)"
}

@test "get_iteration_display formats without max runs" {
    source "$SCRIPT_PATH"
    run get_iteration_display 1 0 0
    assert_output "(1)"
}

# -------------------------------------------------------------
# Codex JSONL result parsing
# -------------------------------------------------------------

@test "parse_codex_result handles valid JSONL with turn.completed" {
    source "$SCRIPT_PATH"
    local result='{"type":"thread.started","thread_id":"x"}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"done"}}
{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":20,"reasoning_output_tokens":0}}'
    run parse_codex_result "$result"
    assert_success
    assert_output "success"
}

@test "parse_codex_result handles invalid JSON" {
    source "$SCRIPT_PATH"
    run parse_codex_result 'not valid json at all'
    assert_failure
    assert_output "invalid_json"
}

@test "parse_codex_result detects turn.failed event" {
    source "$SCRIPT_PATH"
    local result='{"type":"thread.started","thread_id":"x"}
{"type":"turn.failed","error":{"message":"boom"}}'
    run parse_codex_result "$result"
    assert_failure
    assert_output "codex_error"
}

@test "parse_codex_result detects error event" {
    source "$SCRIPT_PATH"
    local result='{"type":"error","message":"upstream rejected"}'
    run parse_codex_result "$result"
    assert_failure
    assert_output "codex_error"
}

@test "parse_codex_result rejects empty input" {
    source "$SCRIPT_PATH"
    run parse_codex_result ""
    assert_failure
    assert_output "invalid_json"
}

@test "extract_codex_final_text returns last agent_message text" {
    source "$SCRIPT_PATH"
    local result='{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"first"}}
{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"second"}}
{"type":"turn.completed","usage":{"input_tokens":1,"cached_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0}}'
    run extract_codex_final_text "$result"
    assert_success
    assert_output "second"
}

@test "extract_codex_final_text returns empty when no agent_message" {
    source "$SCRIPT_PATH"
    local result='{"type":"thread.started","thread_id":"x"}
{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0}}'
    run extract_codex_final_text "$result"
    assert_success
    assert_output ""
}

@test "accumulate_iteration_tokens sums tokens across turn.completed events" {
    source "$SCRIPT_PATH"
    total_input_tokens=0
    total_output_tokens=0
    total_reasoning_tokens=0
    total_cached_input_tokens=0
    LAST_ITER_TOKEN_TOTAL=0

    local result='{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":200,"reasoning_output_tokens":50}}
{"type":"turn.completed","usage":{"input_tokens":5,"cached_input_tokens":0,"output_tokens":10,"reasoning_output_tokens":0}}'

    # Call directly (not via `run`) so global vars accumulate in the current shell.
    accumulate_iteration_tokens "$result"

    # Per-iteration totals: 100+5=105 input, 200+10=210 output, 50+0=50 reasoning, 10+0=10 cached.
    assert_equal "$LAST_ITER_INPUT_TOKENS" "105"
    assert_equal "$LAST_ITER_OUTPUT_TOKENS" "210"
    assert_equal "$LAST_ITER_REASONING_TOKENS" "50"
    assert_equal "$LAST_ITER_CACHED_INPUT_TOKENS" "10"
    assert_equal "$LAST_ITER_TOKEN_TOTAL" "365"

    # Running totals must be updated in the parent shell — the bug was that
    # earlier callers used `var=$(accumulate_iteration_tokens ...)` which ran
    # the function in a subshell, so totals never accumulated.
    assert_equal "$total_input_tokens" "105"
    assert_equal "$total_output_tokens" "210"
    assert_equal "$total_reasoning_tokens" "50"
    assert_equal "$total_cached_input_tokens" "10"

    # A second call should keep accumulating into the running totals.
    accumulate_iteration_tokens "$result"
    assert_equal "$total_input_tokens" "210"
    assert_equal "$total_output_tokens" "420"
    assert_equal "$LAST_ITER_TOKEN_TOTAL" "365"
}

@test "accumulate_iteration_tokens handles no turn.completed events" {
    source "$SCRIPT_PATH"
    total_input_tokens=0
    total_output_tokens=0
    total_reasoning_tokens=0
    total_cached_input_tokens=0
    LAST_ITER_TOKEN_TOTAL=999  # ensure it gets reset

    local result='{"type":"thread.started","thread_id":"x"}'
    accumulate_iteration_tokens "$result"

    assert_equal "$LAST_ITER_TOKEN_TOTAL" "0"
    assert_equal "$total_input_tokens" "0"
}

# -------------------------------------------------------------
# Branch creation
# -------------------------------------------------------------

@test "create_iteration_branch generates correct branch name" {
    source "$SCRIPT_PATH"
    GIT_BRANCH_PREFIX="test-prefix/"
    DRY_RUN="true"

    function date() {
        if [ "$1" == "+%Y-%m-%d" ]; then
            echo "2024-01-01"
        else
            echo "12345678"
        fi
    }
    function openssl() {
        echo "abcdef12"
    }
    export -f date openssl

    run create_iteration_branch "(1/5)" 1
    assert_success
    assert_output --partial "test-prefix/iteration-1/2024-01-01-abcdef12"
}

# -------------------------------------------------------------
# Completion signal detection
# -------------------------------------------------------------

@test "parse_arguments sets default completion values" {
    source "$SCRIPT_PATH"
    assert_equal "$COMPLETION_SIGNAL" "CODEXT_PROJECT_COMPLETE"
    assert_equal "$COMPLETION_THRESHOLD" "3"
}

@test "parse_arguments handles completion-signal flag" {
    source "$SCRIPT_PATH"
    parse_arguments --completion-signal "CUSTOM_SIGNAL"
    assert_equal "$COMPLETION_SIGNAL" "CUSTOM_SIGNAL"
}

@test "parse_arguments handles completion-threshold flag" {
    source "$SCRIPT_PATH"
    parse_arguments --completion-threshold 5
    assert_equal "$COMPLETION_THRESHOLD" "5"
}

@test "validate_arguments fails with invalid completion-threshold" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS="5"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    COMPLETION_THRESHOLD="invalid"
    run validate_arguments
    assert_failure
    assert_output --partial "Error: --completion-threshold must be a positive integer"
}

@test "completion signal detection increments counter" {
    source "$SCRIPT_PATH"
    completion_signal_count=0
    total_input_tokens=0
    total_output_tokens=0
    total_reasoning_tokens=0
    total_cached_input_tokens=0
    COMPLETION_SIGNAL="TEST_COMPLETE"
    COMPLETION_THRESHOLD=3
    ENABLE_COMMITS="false"

    # JSONL with completion signal in the agent_message text
    result='{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"All done. TEST_COMPLETE"}}
{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":20,"reasoning_output_tokens":0}}'

    function git() { return 0; }
    export -f git

    run handle_iteration_success "(1/3)" "$result" "" "main"
    assert_success
    assert_output --partial "Completion signal detected (1/3)"
}

@test "completion signal resets counter when not found" {
    source "$SCRIPT_PATH"
    completion_signal_count=2
    total_input_tokens=0
    total_output_tokens=0
    total_reasoning_tokens=0
    total_cached_input_tokens=0
    COMPLETION_SIGNAL="TEST_COMPLETE"
    COMPLETION_THRESHOLD=3
    ENABLE_COMMITS="false"

    result='{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"Work in progress"}}
{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":20,"reasoning_output_tokens":0}}'

    function git() { return 0; }
    export -f git

    run handle_iteration_success "(1/3)" "$result" "" "main"
    assert_success
    assert_output --partial "Completion signal not found, resetting counter"
}

@test "completion signal is case sensitive" {
    source "$SCRIPT_PATH"
    completion_signal_count=0
    total_input_tokens=0
    total_output_tokens=0
    total_reasoning_tokens=0
    total_cached_input_tokens=0
    COMPLETION_SIGNAL="PROJECT_COMPLETE"
    COMPLETION_THRESHOLD=3
    ENABLE_COMMITS="false"

    result='{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"project_complete"}}
{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":20,"reasoning_output_tokens":0}}'

    function git() { return 0; }
    export -f git

    run handle_iteration_success "(1/3)" "$result" "" "main"
    assert_success
    refute_output --partial "Completion signal detected"
}

# -------------------------------------------------------------
# Completion summary
# -------------------------------------------------------------

@test "show_completion_summary shows signal message with token totals" {
    source "$SCRIPT_PATH"
    completion_signal_count=3
    total_input_tokens=1000
    total_output_tokens=500
    total_reasoning_tokens=100
    COMPLETION_THRESHOLD=3
    MAX_RUNS=10

    run show_completion_summary
    assert_success
    assert_output --partial "Project completed!"
    assert_output --partial "Total tokens:"
}

@test "show_completion_summary shows signal message without tokens" {
    source "$SCRIPT_PATH"
    completion_signal_count=3
    total_input_tokens=0
    total_output_tokens=0
    total_reasoning_tokens=0
    COMPLETION_THRESHOLD=3
    MAX_RUNS=10

    run show_completion_summary
    assert_success
    assert_output --partial "Project completed!"
    refute_output --partial "Total tokens"
}

# -------------------------------------------------------------
# run_codex_iteration
# -------------------------------------------------------------

@test "run_codex_iteration captures stderr to error log" {
    source "$SCRIPT_PATH"

    function codex() {
        echo "This is an error message" >&2
        return 1
    }
    export -f codex

    local error_log=$(mktemp)
    run run_codex_iteration "test prompt" "--json" "$error_log"
    assert_failure

    assert [ -f "$error_log" ]
    assert [ -s "$error_log" ]
    local error_content=$(cat "$error_log")
    assert_equal "$error_content" "This is an error message"

    rm -f "$error_log"
}

@test "run_codex_iteration falls back to helpful message on silent failure" {
    source "$SCRIPT_PATH"

    function codex() { return 1; }
    export -f codex

    local error_log=$(mktemp)
    run run_codex_iteration "test prompt" "--json" "$error_log"
    assert_failure

    local error_content=$(cat "$error_log")
    if ! echo "$error_content" | grep -q "Codex CLI exited with code 1"; then
        fail "Error log should mention exit code"
    fi
    if ! echo "$error_content" | grep -q "codex login status"; then
        fail "Error log should suggest auth check"
    fi

    rm -f "$error_log"
}

@test "run_codex_iteration dry run mode" {
    source "$SCRIPT_PATH"
    DRY_RUN="true"
    local error_log=$(mktemp)

    run run_codex_iteration "test prompt" "--json" "$error_log"
    assert_success
    assert_output --partial "(DRY RUN) Would run Codex CLI"

    rm -f "$error_log"
}

@test "run_codex_iteration extracts error from JSON stdout" {
    source "$SCRIPT_PATH"

    function codex() {
        echo '{"type":"turn.failed","error":{"message":"Rate limit hit"}}' >&1
        return 1
    }
    function jq() { command jq "$@"; }
    export -f codex jq

    local error_log=$(mktemp)
    run run_codex_iteration "test prompt" "--json" "$error_log"
    assert_failure

    local error_content=$(cat "$error_log")
    if ! echo "$error_content" | grep -q "Rate limit hit"; then
        echo "Got: $error_content"
        fail "Error log should contain extracted JSON error message"
    fi

    rm -f "$error_log"
}

# -------------------------------------------------------------
# Update mechanism
# -------------------------------------------------------------

@test "get_latest_version fails when UPDATE_REPO_OWNER is placeholder" {
    source "$SCRIPT_PATH"
    UPDATE_REPO_OWNER="OWNER_PLACEHOLDER"

    function gh() { echo "v9.9.9"; return 0; }
    export -f gh

    run get_latest_version
    assert_failure
}

@test "get_latest_version returns version when configured" {
    source "$SCRIPT_PATH"
    UPDATE_REPO_OWNER="someone"
    UPDATE_REPO_NAME="codext"

    function gh() {
        if [ "$1" = "release" ] && [ "$2" = "view" ]; then
            echo "v0.10.0"
            return 0
        fi
        return 1
    }
    export -f gh

    run get_latest_version
    assert_success
    assert_output "v0.10.0"
}

@test "compare_versions detects equal versions" {
    source "$SCRIPT_PATH"
    run compare_versions "v0.9.1" "v0.9.1"
    assert [ $status -eq 0 ]
}

@test "compare_versions detects older version" {
    source "$SCRIPT_PATH"
    run compare_versions "v0.9.1" "v0.10.0"
    assert [ $status -eq 1 ]
}

@test "compare_versions detects newer version" {
    source "$SCRIPT_PATH"
    run compare_versions "v0.10.0" "v0.9.1"
    assert [ $status -eq 2 ]
}

@test "compare_versions handles pre-release versions" {
    source "$SCRIPT_PATH"
    run compare_versions "v1.0.0-beta" "v1.0.0"
    assert [ $status -eq 0 ]
}

@test "check_for_updates skips when updates disabled" {
    source "$SCRIPT_PATH"
    DISABLE_UPDATES="true"
    function get_latest_version() { echo "should not run"; return 1; }
    export -f get_latest_version

    run check_for_updates false
    assert_success
    assert_output ""
}

@test "handle_update_command skips when updates disabled" {
    source "$SCRIPT_PATH"
    DISABLE_UPDATES="true"
    run handle_update_command
    assert_success
    assert_output --partial "Updates are disabled"
}

@test "handle_update_command shows already on latest when versions match" {
    source "$SCRIPT_PATH"
    VERSION="v0.10.0"
    function get_latest_version() { echo "v0.10.0"; return 0; }
    export -f get_latest_version

    run handle_update_command
    assert_success
    assert_output --partial "You're already on the latest version"
}

@test "parse_update_flags handles auto-update and disable-updates" {
    source "$SCRIPT_PATH"
    AUTO_UPDATE="false"
    DISABLE_UPDATES="false"
    parse_update_flags --auto-update --disable-updates
    assert_equal "$AUTO_UPDATE" "true"
    assert_equal "$DISABLE_UPDATES" "true"
}

# -------------------------------------------------------------
# detect_github_repo
# -------------------------------------------------------------

@test "detect_github_repo detects HTTPS URL" {
    source "$SCRIPT_PATH"
    function git() {
        if [ "$1" = "rev-parse" ] && [ "$2" = "--git-dir" ]; then
            return 0
        elif [ "$1" = "remote" ] && [ "$2" = "get-url" ] && [ "$3" = "origin" ]; then
            echo "https://github.com/testowner/testrepo.git"
            return 0
        fi
        return 1
    }
    export -f git

    run detect_github_repo
    assert_success
    assert_output "testowner testrepo"
}

@test "detect_github_repo detects SSH URL" {
    source "$SCRIPT_PATH"
    function git() {
        if [ "$1" = "rev-parse" ] && [ "$2" = "--git-dir" ]; then
            return 0
        elif [ "$1" = "remote" ] && [ "$2" = "get-url" ] && [ "$3" = "origin" ]; then
            echo "git@github.com:testowner/testrepo.git"
            return 0
        fi
        return 1
    }
    export -f git

    run detect_github_repo
    assert_success
    assert_output "testowner testrepo"
}

@test "detect_github_repo fails when not in git repo" {
    source "$SCRIPT_PATH"
    function git() { return 1; }
    export -f git

    run detect_github_repo
    assert_failure
}

@test "detect_github_repo fails for non-GitHub URL" {
    source "$SCRIPT_PATH"
    function git() {
        if [ "$1" = "rev-parse" ] && [ "$2" = "--git-dir" ]; then
            return 0
        elif [ "$1" = "remote" ] && [ "$2" = "get-url" ] && [ "$3" = "origin" ]; then
            echo "https://gitlab.com/testowner/testrepo.git"
            return 0
        fi
        return 1
    }
    export -f git

    run detect_github_repo
    assert_failure
}

@test "validate_arguments auto-detects owner and repo" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS="5"
    ENABLE_COMMITS="true"
    GITHUB_OWNER=""
    GITHUB_REPO=""

    function detect_github_repo() {
        echo "autoowner autorepo"
        return 0
    }
    export -f detect_github_repo

    validate_arguments

    assert_equal "$GITHUB_OWNER" "autoowner"
    assert_equal "$GITHUB_REPO" "autorepo"
}

# -------------------------------------------------------------
# Duration parsing
# -------------------------------------------------------------

@test "parse_duration parses hours, minutes, seconds" {
    source "$SCRIPT_PATH"
    run parse_duration "2h"
    assert_success
    assert_output "7200"

    run parse_duration "30m"
    assert_success
    assert_output "1800"

    run parse_duration "45s"
    assert_success
    assert_output "45"
}

@test "parse_duration parses combined durations" {
    source "$SCRIPT_PATH"
    run parse_duration "1h30m"
    assert_success
    assert_output "5400"

    run parse_duration "2h15m30s"
    assert_success
    assert_output "8130"
}

@test "parse_duration fails with invalid format" {
    source "$SCRIPT_PATH"
    run parse_duration "abc"
    assert_failure

    run parse_duration ""
    assert_failure

    run parse_duration "0h"
    assert_failure
}

@test "format_duration formats correctly" {
    source "$SCRIPT_PATH"
    run format_duration 7200
    assert_success
    assert_output "2h"

    run format_duration 5400
    assert_success
    assert_output "1h30m"

    run format_duration 0
    assert_success
    assert_output "0s"
}

# -------------------------------------------------------------
# format_tokens
# -------------------------------------------------------------

@test "format_tokens formats numbers with thousands separators" {
    source "$SCRIPT_PATH"
    run format_tokens 1000
    assert_success
    assert_output "1,000"

    run format_tokens 1234567
    assert_success
    assert_output "1,234,567"

    run format_tokens 0
    assert_success
    assert_output "0"

    run format_tokens 999
    assert_success
    assert_output "999"
}

# -------------------------------------------------------------
# CI retry / comment review flag handling
# -------------------------------------------------------------

@test "parse_arguments sets default CI retry enabled" {
    source "$SCRIPT_PATH"
    assert_equal "$CI_RETRY_ENABLED" "true"
    assert_equal "$CI_RETRY_MAX_ATTEMPTS" "1"
}

@test "parse_arguments handles disable-ci-retry flag" {
    source "$SCRIPT_PATH"
    CI_RETRY_ENABLED="true"
    parse_arguments --disable-ci-retry
    assert_equal "$CI_RETRY_ENABLED" "false"
}

@test "parse_arguments handles ci-retry-max flag" {
    source "$SCRIPT_PATH"
    CI_RETRY_MAX_ATTEMPTS="1"
    parse_arguments --ci-retry-max 3
    assert_equal "$CI_RETRY_MAX_ATTEMPTS" "3"
}

@test "validate_arguments fails with invalid ci-retry-max" {
    source "$SCRIPT_PATH"
    PROMPT="test"
    MAX_RUNS="5"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"
    CI_RETRY_MAX_ATTEMPTS="invalid"
    run validate_arguments
    assert_failure
    assert_output --partial "Error: --ci-retry-max must be a positive integer"
}

@test "parse_arguments sets default comment review enabled" {
    source "$SCRIPT_PATH"
    assert_equal "$COMMENT_REVIEW_ENABLED" "true"
    assert_equal "$COMMENT_REVIEW_MAX_ATTEMPTS" "1"
}

@test "parse_arguments handles disable-comment-review flag" {
    source "$SCRIPT_PATH"
    COMMENT_REVIEW_ENABLED="true"
    parse_arguments --disable-comment-review
    assert_equal "$COMMENT_REVIEW_ENABLED" "false"
}

# -------------------------------------------------------------
# get_failed_run_id
# -------------------------------------------------------------

@test "get_failed_run_id returns run ID for failed workflow" {
    source "$SCRIPT_PATH"
    function gh() {
        if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
            echo "abc123"
            return 0
        elif [ "$1" = "run" ] && [ "$2" = "list" ]; then
            echo "12345"
            return 0
        fi
        return 1
    }
    export -f gh

    run get_failed_run_id 123 "owner" "repo"
    assert_success
    assert_output "12345"
}

@test "get_failed_run_id returns failure when no failed runs" {
    source "$SCRIPT_PATH"
    function gh() {
        if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
            echo "abc123"
            return 0
        elif [ "$1" = "run" ] && [ "$2" = "list" ]; then
            echo "null"
            return 0
        fi
        return 1
    }
    export -f gh

    run get_failed_run_id 123 "owner" "repo"
    assert_failure
}

# -------------------------------------------------------------
# check_pr_comments
# -------------------------------------------------------------

@test "check_pr_comments returns 0 when comments exist" {
    source "$SCRIPT_PATH"
    function gh() {
        if [ "$1" = "api" ]; then
            if echo "$2" | grep -q "pulls.*comments"; then
                echo "2"
                return 0
            elif echo "$2" | grep -q "issues.*comments"; then
                echo "1"
                return 0
            fi
        fi
        return 1
    }
    export -f gh

    run check_pr_comments "123" "owner" "repo" "[1/5]"
    assert_success
    assert_output --partial "Found 3 comment(s)"
}

@test "check_pr_comments returns 1 when no comments" {
    source "$SCRIPT_PATH"
    function gh() {
        if [ "$1" = "api" ]; then
            echo "0"
            return 0
        fi
        return 1
    }
    export -f gh

    run check_pr_comments "123" "owner" "repo" "[1/5]"
    assert_failure
    assert_output --partial "No comments found"
}

# -------------------------------------------------------------
# Dry-run end-to-end commit
# -------------------------------------------------------------

@test "codext_commit dry run shows PR merged message" {
    source "$SCRIPT_PATH"

    DRY_RUN="true"
    ENABLE_COMMITS="true"
    GITHUB_OWNER="user"
    GITHUB_REPO="repo"

    function git() {
        case "$1" in
            rev-parse)
                if [ "$2" = "--git-dir" ]; then
                    return 0
                elif [ "$2" = "--abbrev-ref" ]; then
                    echo "main"
                fi
                ;;
            diff)
                return 1  # there are changes
                ;;
            ls-files)
                echo ""
                ;;
            checkout|branch)
                return 0
                ;;
        esac
        return 0
    }
    export -f git

    run codext_commit "(1/1)" "test-branch" "main"
    assert_success
    assert_output --partial "(DRY RUN) PR merged: <commit title would appear here>"
}

# -------------------------------------------------------------
# wait_for_pr_checks waiting message
# -------------------------------------------------------------

@test "wait_for_pr_checks prints initial waiting message once" {
    source "$SCRIPT_PATH"

    echo "0" > "$BATS_TEST_TMPDIR/gh_call_count"

    function gh() {
        if [ "$1" = "pr" ] && [ "$2" = "checks" ]; then
            local count=$(cat "$BATS_TEST_TMPDIR/gh_call_count")
            count=$((count + 1))
            echo "$count" > "$BATS_TEST_TMPDIR/gh_call_count"

            if [ $count -eq 1 ]; then
                echo "[]"
            else
                echo '[{"state": "completed", "bucket": "success"}]'
            fi
            return 0
        elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
            echo '{"reviewDecision": "APPROVED", "reviewRequests": []}'
            return 0
        fi
        return 1
    }
    function sleep() { return 0; }
    export -f gh sleep

    run bash -c "
        source '$SCRIPT_PATH'
        wait_for_pr_checks 123 'owner' 'repo' '(1/1)' 2>&1
    "

    assert_output --partial "⏳ Waiting for checks to start"
    assert_output --partial "."

    rm -f "$BATS_TEST_TMPDIR/gh_call_count"
}

@test "wait_for_pr_checks does not print waiting message when checks found immediately" {
    source "$SCRIPT_PATH"

    function gh() {
        if [ "$1" = "pr" ] && [ "$2" = "checks" ]; then
            echo '[{"state": "completed", "bucket": "success"}]'
            return 0
        elif [ "$1" = "pr" ] && [ "$2" = "view" ]; then
            echo '{"reviewDecision": "APPROVED", "reviewRequests": []}'
            return 0
        fi
        return 1
    }
    function sleep() { return 0; }
    export -f gh sleep

    run bash -c "
        source '$SCRIPT_PATH'
        wait_for_pr_checks 123 'owner' 'repo' '(1/1)' 2>&1
    "

    refute_output --partial "⏳ Waiting for checks to start"
    assert_output --partial "Found"
}
