#!/bin/bash

VERSION="v0.1.1"

# Repo coordinates used for self-update checks and release-note display.
UPDATE_REPO_OWNER="sanchitmonga22"
UPDATE_REPO_NAME="Codext"

# Default flags forwarded to every `codex exec` invocation.
#   --json                              emit newline-delimited ThreadEvent stream we can parse
#   --skip-git-repo-check               allow running outside a git repo
#   --full-auto                         workspace-write sandbox + on-request approvals; safe-by-default automation preset
# To grant unrestricted access (network + writes anywhere), pass --yolo on the command line; it's
# forwarded through EXTRA_CODEX_FLAGS and overrides --full-auto.
ADDITIONAL_FLAGS="--json --skip-git-repo-check --full-auto"

NOTES_FILE="SHARED_TASK_NOTES.md"
AUTO_UPDATE=false
DISABLE_UPDATES=false

PROMPT_JQ_INSTALL="Please install jq for JSON parsing"

PROMPT_COMMIT_MESSAGE="Please review all uncommitted changes in the git repository (both modified and new files). Write a commit message with: (1) a short one-line summary, (2) two newlines, (3) then a detailed explanation. Do not include any footers or metadata like 'Generated with Codex' or 'Co-Authored-By'. Feel free to look at the last few commits to get a sense of the commit message style for consistency. First run 'git add .' to stage all changes including new untracked files, then commit using 'git commit -m \"your message\"' (don't push, just commit, no need to ask for confirmation)."

PROMPT_WORKFLOW_CONTEXT="## CONTINUOUS WORKFLOW CONTEXT

This is part of a continuous development loop where work happens incrementally across multiple iterations. You might run once, then a human developer might make changes, then you run again, and so on. This could happen daily or on any schedule.

**Important**: You don't need to complete the entire goal in one iteration. Just make meaningful progress on one thing, then leave clear notes for the next iteration (human or AI). Think of it as a relay race where you're passing the baton.

**Do NOT commit or push changes** - The automation will handle committing and pushing your changes after you finish. Just focus on making the code changes.

**Project Completion Signal**: If you determine that not just your current task but the ENTIRE project goal is fully complete (nothing more to be done on the overall goal), only include the exact phrase \"COMPLETION_SIGNAL_PLACEHOLDER\" in your response. Only use this when absolutely certain that the whole project is finished, not just your individual task. We will stop working on this project when multiple developers independently determine that the project is complete.

## PRIMARY GOAL"

PROMPT_NOTES_UPDATE_EXISTING="Update the \`$NOTES_FILE\` file with relevant context for the next iteration. Add new notes and remove outdated information to keep it current and useful."

PROMPT_NOTES_CREATE_NEW="Create a \`$NOTES_FILE\` file with relevant context and instructions for the next iteration."

PROMPT_NOTES_GUIDELINES="

This file helps coordinate work across iterations (both human and AI developers). It should:

- Contain relevant context and instructions for the next iteration
- Stay concise and actionable (like a notes file, not a detailed report)
- Help the next developer understand what to do next

The file should NOT include:
- Lists of completed work or full reports
- Information that can be discovered by running tests/coverage
- Unnecessary details"

PROMPT_REVIEWER_CONTEXT="## CODE REVIEW CONTEXT

You are performing a review pass on changes just made by another developer. This is NOT a new feature implementation - you are reviewing and validating existing changes using the instructions given below by the user. Feel free to use git commands to see what changes were made if it's helpful to you.

**Do NOT commit or push changes** - The automation will handle committing and pushing your changes after you finish. Just focus on validating and fixing any issues."

PROMPT_CI_FIX_CONTEXT="## CI FAILURE FIX CONTEXT

You are analyzing and fixing a CI/CD failure for a pull request.

**Your task:**
1. Inspect the failed CI workflow using the commands below
2. Analyze the error logs to understand what went wrong
3. Make the necessary code changes to fix the issue
4. Stage and commit your changes (they will be pushed to update the PR)

**Commands to inspect CI failures:**
- \`gh run list --status failure --limit 3\` - List recent failed runs
- \`gh run view <RUN_ID> --log-failed\` - View failed job logs (shorter output)
- \`gh run view <RUN_ID> --log\` - View full logs for a specific run

**Important:**
- Focus only on fixing the CI failure, not adding new features
- Make minimal changes necessary to pass CI
- If the failure seems unfixable (e.g., flaky test, infrastructure issue), explain why in your response"

PROMPT_COMMENT_REVIEW_CONTEXT="## PR COMMENT REVIEW CONTEXT

You are addressing review comments on a pull request.

**Your task:**
1. Use \`gh api repos/{owner}/{repo}/pulls/{pr}/comments\` to read inline code review comments
2. Use \`gh api repos/{owner}/{repo}/issues/{pr}/comments\` to read PR-level comments
3. Analyze each comment and determine if it requires code changes
4. Make the necessary code changes to address the feedback
5. Stage, commit, AND PUSH your changes with a clear commit message describing what comments you addressed

**Important:**
- Focus only on addressing the review comments, not adding new features
- Make minimal changes necessary to address the feedback
- If a comment is just informational or a question, no code changes are needed for it"

PROMPT=""
MAX_RUNS=""
MAX_TOKENS=""
MAX_DURATION=""
ENABLE_COMMITS=true
DISABLE_BRANCHES=false
GIT_BRANCH_PREFIX="codext/"
MERGE_STRATEGY="squash"
GITHUB_OWNER=""
GITHUB_REPO=""
WORKTREE_NAME=""
WORKTREE_BASE_DIR="../codext-worktrees"
CLEANUP_WORKTREE=false
LIST_WORKTREES=false
DRY_RUN=false
COMPLETION_SIGNAL="CODEXT_PROJECT_COMPLETE"
COMPLETION_THRESHOLD=3
ERROR_LOG=""
LAST_MESSAGE_FILE=""
error_count=0
extra_iterations=0
successful_iterations=0
total_input_tokens=0
total_output_tokens=0
total_reasoning_tokens=0
total_cached_input_tokens=0
completion_signal_count=0
i=1
EXTRA_CODEX_FLAGS=()
REVIEW_PROMPT=""
start_time=""
CI_RETRY_ENABLED=true
CI_RETRY_MAX_ATTEMPTS=1
COMMENT_REVIEW_ENABLED=true
COMMENT_REVIEW_MAX_ATTEMPTS=1

parse_duration() {
    # Parse a duration string like "2h", "30m", "1h30m", "90s" to seconds
    # Returns: number of seconds, or empty string on error
    local duration_str="$1"

    # Remove all whitespace
    duration_str=$(echo "$duration_str" | tr -d '[:space:]')

    if [ -z "$duration_str" ]; then
        return 1
    fi

    local total_seconds=0
    local remaining="$duration_str"

    # Parse hours (e.g., "2h" or "2H")
    if [[ "$remaining" =~ ([0-9]+)[hH] ]]; then
        local hours="${BASH_REMATCH[1]}"
        total_seconds=$((total_seconds + hours * 3600))
        remaining="${remaining/${BASH_REMATCH[0]}/}"
    fi

    # Parse minutes (e.g., "30m" or "30M")
    if [[ "$remaining" =~ ([0-9]+)[mM] ]]; then
        local minutes="${BASH_REMATCH[1]}"
        total_seconds=$((total_seconds + minutes * 60))
        remaining="${remaining/${BASH_REMATCH[0]}/}"
    fi

    # Parse seconds (e.g., "45s" or "45S")
    if [[ "$remaining" =~ ([0-9]+)[sS] ]]; then
        local seconds="${BASH_REMATCH[1]}"
        total_seconds=$((total_seconds + seconds))
        remaining="${remaining/${BASH_REMATCH[0]}/}"
    fi

    if [ -n "$remaining" ]; then
        return 1
    fi

    if [ $total_seconds -eq 0 ]; then
        return 1
    fi

    echo "$total_seconds"
    return 0
}

format_duration() {
    local seconds="$1"

    if [ -z "$seconds" ] || [ "$seconds" -eq 0 ]; then
        echo "0s"
        return
    fi

    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    local result=""
    if [ $hours -gt 0 ]; then
        result="${hours}h"
    fi
    if [ $minutes -gt 0 ]; then
        result="${result}${minutes}m"
    fi
    if [ $secs -gt 0 ] || [ -z "$result" ]; then
        result="${result}${secs}s"
    fi

    echo "$result"
}

format_tokens() {
    # Format a number with thousands separators (e.g., 1234567 -> "1,234,567")
    local n="$1"
    if [ -z "$n" ] || [ "$n" -eq 0 ]; then
        echo "0"
        return
    fi
    # Use awk for portable thousands grouping
    awk -v n="$n" 'BEGIN{
        s=sprintf("%d", n);
        out="";
        len=length(s);
        for(i=1;i<=len;i++){
            out = out substr(s,i,1);
            if((len-i)%3==0 && i<len) out=out",";
        }
        print out;
    }'
}

show_help() {
    cat << EOF
Codext - Codex, in a Loopt. Run OpenAI Codex CLI iteratively with automatic PR management.

USAGE:
    codext -p "prompt" (-m max-runs | --max-tokens max-tokens | --max-duration duration) [--owner owner] [--repo repo] [options]
    codext update

REQUIRED OPTIONS:
    -p, --prompt <text>           The prompt/goal for Codex CLI to work on
    -m, --max-runs <number>       Maximum number of successful iterations (use 0 for unlimited with --max-tokens or --max-duration)
    --max-tokens <number>         Maximum total tokens (input+output+reasoning) to spend across all iterations
    --max-duration <duration>     Maximum duration to run (e.g., "2h", "30m", "1h30m") (alternative to --max-runs)

OPTIONAL FLAGS:
    -h, --help                    Show this help message
    -v, --version                 Show version information
    --owner <owner>               GitHub repository owner (auto-detected from git remote if not provided)
    --repo <repo>                 GitHub repository name (auto-detected from git remote if not provided)
    --disable-commits             Disable automatic commits and PR creation
    --disable-branches            Commit on current branch without creating branches or PRs
    --auto-update                 Automatically install updates when available
    --disable-updates             Skip all update checks and prompts
    --git-branch-prefix <prefix>  Branch prefix for iterations (default: "codext/")
    --merge-strategy <strategy>   PR merge strategy: squash, merge, or rebase (default: "squash")
    --notes-file <file>           Shared notes file for iteration context (default: "SHARED_TASK_NOTES.md")
    --worktree <name>             Run in a git worktree for parallel execution (creates if needed)
    --worktree-base-dir <path>    Base directory for worktrees (default: "../codext-worktrees")
    --cleanup-worktree            Remove worktree after completion
    --list-worktrees              List all active git worktrees and exit
    --dry-run                     Simulate execution without making changes
    --completion-signal <phrase>  Phrase that agents output when project is complete (default: "CODEXT_PROJECT_COMPLETE")
    --completion-threshold <num>  Number of consecutive signals to stop early (default: 3)
    -r, --review-prompt <text>    Run a reviewer pass after each iteration to validate changes
                                  (e.g., run build/lint/tests and fix any issues)
    --disable-ci-retry            Disable automatic CI failure retry (enabled by default)
    --ci-retry-max <number>       Maximum CI fix attempts per PR (default: 1)
    --disable-comment-review      Disable automatic PR comment review (enabled by default)
    --comment-review-max <number> Maximum comment review attempts per PR (default: 1)

CODEX-SPECIFIC PASSTHROUGH FLAGS:
    Any unrecognized flag is forwarded directly to \`codex exec\`. Useful examples:
    --model <name>                Override the model (e.g., gpt-5.5, gpt-5.4)
    --yolo                        Bypass approvals and sandbox entirely (overrides default --full-auto)
    --sandbox <mode>              read-only | workspace-write | danger-full-access
    --add-dir <path>              Grant Codex write access to an additional directory
    -c key=value                  Inline configuration override (forwarded to codex)

COMMANDS:
    update                        Check for and install the latest version

EXAMPLES:
    # Run 5 iterations to fix bugs
    codext -p "Fix all linter errors" -m 5 --owner myuser --repo myproject

    # Run with a token budget (sum of input+output+reasoning across all iterations)
    codext -p "Add tests" --max-tokens 2000000 --owner myuser --repo myproject

    # Run for a maximum duration (time-boxed)
    codext -p "Add documentation" --max-duration 2h --owner myuser --repo myproject

    # Run for 30 minutes
    codext -p "Refactor module" --max-duration 30m --owner myuser --repo myproject

    # Run without commits (testing mode)
    codext -p "Refactor code" -m 3 --disable-commits

    # Run with commits on current branch (no branches or PRs)
    codext -p "Quick fixes" -m 3 --disable-branches

    # Use custom branch prefix and merge strategy
    codext -p "Feature work" -m 10 --owner myuser --repo myproject \\
        --git-branch-prefix "ai/" --merge-strategy merge

    # Combine duration and token limits (whichever comes first)
    codext -p "Add tests" --max-duration 1h30m --max-tokens 1000000 --owner myuser --repo myproject

    # Run in a worktree for parallel execution
    codext -p "Add unit tests" -m 5 --owner myuser --repo myproject --worktree instance-1

    # Run multiple instances in parallel (in different terminals)
    codext -p "Task A" -m 5 --owner myuser --repo myproject --worktree task-a
    codext -p "Task B" -m 5 --owner myuser --repo myproject --worktree task-b

    # List all active worktrees
    codext --list-worktrees

    # Use a specific Codex model (forwarded as a passthrough flag)
    codext -p "Add tests" -m 5 --model gpt-5.5 --owner myuser --repo myproject

    # Use a reviewer to validate and fix changes after each iteration
    codext -p "Add new feature" -m 5 --owner myuser --repo myproject \\
        -r "Run npm test and npm run lint, fix any failures"

    # Allow up to 2 CI fix attempts per PR (default is 1)
    codext -p "Add tests" -m 5 --owner myuser --repo myproject --ci-retry-max 2

    # Disable automatic CI failure retry
    codext -p "Add tests" -m 5 --owner myuser --repo myproject --disable-ci-retry

    # Check for and install updates
    codext update

REQUIREMENTS:
    - Codex CLI (https://github.com/openai/codex) - authenticated with 'codex login'
    - GitHub CLI (gh) - authenticated with 'gh auth login'
    - jq - JSON parsing utility
    - Git repository (unless --disable-commits is used)

NOTE:
    codext automatically checks for updates at startup. You can press 'N' to skip the update.
    Codex CLI does not report dollar costs in its event stream; use --max-tokens for budget control.

For more information, visit: https://github.com/${UPDATE_REPO_OWNER}/${UPDATE_REPO_NAME}
EOF
}

show_version() {
    echo "codext version $VERSION"
}

get_latest_version() {
    local latest_version
    if ! command -v gh &> /dev/null; then
        return 1
    fi

    if [ "$UPDATE_REPO_OWNER" = "OWNER_PLACEHOLDER" ]; then
        return 1
    fi

    latest_version=$(gh release view --repo "${UPDATE_REPO_OWNER}/${UPDATE_REPO_NAME}" --json tagName --jq '.tagName' 2>/dev/null)
    if [ -z "$latest_version" ]; then
        return 1
    fi

    echo "$latest_version"
    return 0
}

convert_gitmoji() {
    sed -e 's/:sparkles:/✨/g' \
        -e 's/:bug:/🐛/g' \
        -e 's/:bookmark:/🔖/g' \
        -e 's/:recycle:/♻️/g' \
        -e 's/:art:/🎨/g' \
        -e 's/:pencil:/✏️/g' \
        -e 's/:memo:/📝/g' \
        -e 's/:construction_worker:/👷/g' \
        -e 's/:rocket:/🚀/g' \
        -e 's/:white_check_mark:/✅/g' \
        -e 's/:lock:/🔒/g' \
        -e 's/:fire:/🔥/g' \
        -e 's/:ambulance:/🚑/g' \
        -e 's/:lipstick:/💄/g' \
        -e 's/:rotating_light:/🚨/g' \
        -e 's/:construction:/🚧/g' \
        -e 's/:green_heart:/💚/g' \
        -e 's/:arrow_down:/⬇️/g' \
        -e 's/:arrow_up:/⬆️/g' \
        -e 's/:pushpin:/📌/g' \
        -e 's/:tada:/🎉/g' \
        -e 's/:wrench:/🔧/g' \
        -e 's/:hammer:/🔨/g' \
        -e 's/:package:/📦/g' \
        -e 's/:truck:/🚚/g' \
        -e 's/:bento:/🍱/g' \
        -e 's/:wheelchair:/♿/g' \
        -e 's/:bulb:/💡/g' \
        -e 's/:beers:/🍻/g' \
        -e 's/:speech_balloon:/💬/g' \
        -e 's/:card_file_box:/🗃️/g' \
        -e 's/:loud_sound:/🔊/g' \
        -e 's/:mute:/🔇/g' \
        -e 's/:busts_in_silhouette:/👥/g' \
        -e 's/:children_crossing:/🚸/g' \
        -e 's/:building_construction:/🏗️/g' \
        -e 's/:iphone:/📱/g' \
        -e 's/:clown_face:/🤡/g' \
        -e 's/:egg:/🥚/g' \
        -e 's/:see_no_evil:/🙈/g' \
        -e 's/:camera_flash:/📸/g' \
        -e 's/:alembic:/⚗️/g' \
        -e 's/:mag:/🔍/g' \
        -e 's/:label:/🏷️/g' \
        -e 's/:seedling:/🌱/g' \
        -e 's/:triangular_flag_on_post:/🚩/g' \
        -e 's/:goal_net:/🥅/g' \
        -e 's/:dizzy:/💫/g' \
        -e 's/:wastebasket:/🗑️/g' \
        -e 's/:passport_control:/🛂/g' \
        -e 's/:adhesive_bandage:/🩹/g' \
        -e 's/:monocle_face:/🧐/g' \
        -e 's/:coffin:/⚰️/g' \
        -e 's/:test_tube:/🧪/g' \
        -e 's/:necktie:/👔/g' \
        -e 's/:stethoscope:/🩺/g' \
        -e 's/:bricks:/🧱/g' \
        -e 's/:technologist:/🧑‍💻/g' \
        -e 's/:zap:/⚡/g' \
        -e 's/:heavy_plus_sign:/➕/g' \
        -e 's/:heavy_minus_sign:/➖/g' \
        -e 's/:twisted_rightwards_arrows:/🔀/g' \
        -e 's/:rewind:/⏪/g' \
        -e 's/:boom:/💥/g' \
        -e 's/:ok_hand:/👌/g' \
        -e 's/:new:/🆕/g' \
        -e 's/:up:/🆙/g'
}

get_release_notes() {
    local version="$1"
    if ! command -v gh &> /dev/null; then
        return 1
    fi
    if [ "$UPDATE_REPO_OWNER" = "OWNER_PLACEHOLDER" ]; then
        return 1
    fi

    local notes
    notes=$(gh release view "$version" --repo "${UPDATE_REPO_OWNER}/${UPDATE_REPO_NAME}" --json body --jq '.body' 2>/dev/null)
    if [ -z "$notes" ]; then
        return 1
    fi

    echo "$notes" | convert_gitmoji
    return 0
}

compare_versions() {
    local ver1="$1"
    local ver2="$2"

    ver1="${ver1#v}"
    ver2="${ver2#v}"

    ver1="${ver1%%-*}"
    ver2="${ver2%%-*}"

    if [ "$ver1" = "$ver2" ]; then
        return 0
    fi

    local IFS=.
    local i ver1_arr ver2_arr
    read -ra ver1_arr <<< "$ver1"
    read -ra ver2_arr <<< "$ver2"

    for ((i=${#ver1_arr[@]}; i<${#ver2_arr[@]}; i++)); do
        ver1_arr[i]=0
    done
    for ((i=${#ver2_arr[@]}; i<${#ver1_arr[@]}; i++)); do
        ver2_arr[i]=0
    done

    for ((i=0; i<${#ver1_arr[@]}; i++)); do
        local c1="${ver1_arr[i]}"
        local c2="${ver2_arr[i]}"
        if [[ "$c1" =~ ^[0-9]+$ ]] && [[ "$c2" =~ ^[0-9]+$ ]]; then
            if ((10#$c1 < 10#$c2)); then
                return 1
            fi
            if ((10#$c1 > 10#$c2)); then
                return 2
            fi
        else
            if [[ "$c1" < "$c2" ]]; then
                return 1
            fi
            if [[ "$c1" > "$c2" ]]; then
                return 2
            fi
        fi
    done

    return 0
}

get_script_path() {
    local script_path
    script_path=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
    echo "$script_path"
}

download_and_install_update() {
    local latest_version="$1"
    local script_path="$2"

    if [ "$UPDATE_REPO_OWNER" = "OWNER_PLACEHOLDER" ]; then
        echo "❌ Updates are disabled in this build (UPDATE_REPO_OWNER not configured)" >&2
        return 1
    fi

    echo "📥 Downloading version $latest_version..." >&2

    local temp_file=$(mktemp)
    local download_url="https://raw.githubusercontent.com/${UPDATE_REPO_OWNER}/${UPDATE_REPO_NAME}/${latest_version}/codext.sh"
    local checksum_url="https://raw.githubusercontent.com/${UPDATE_REPO_OWNER}/${UPDATE_REPO_NAME}/${latest_version}/codext.sh.sha256"
    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        echo "❌ Failed to download update" >&2
        rm -f "$temp_file"
        return 1
    fi

    local checksum_file=$(mktemp)
    if ! curl -fsSL "$checksum_url" -o "$checksum_file"; then
        echo "❌ Failed to download checksum file" >&2
        rm -f "$temp_file" "$checksum_file"
        return 1
    fi

    local expected_checksum
    expected_checksum=$(cat "$checksum_file" | awk '{print $1}')
    local actual_checksum
    actual_checksum=$(sha256sum "$temp_file" | awk '{print $1}')
    if [ "$expected_checksum" != "$actual_checksum" ]; then
        echo "❌ Checksum verification failed! Update aborted." >&2
        rm -f "$temp_file" "$checksum_file"
        return 1
    fi
    rm -f "$checksum_file"

    if ! bash -n "$temp_file" 2>/dev/null; then
        echo "❌ Downloaded file has invalid syntax" >&2
        rm -f "$temp_file"
        return 1
    fi

    chmod +x "$temp_file"

    if ! mv "$temp_file" "$script_path"; then
        echo "❌ Failed to replace script (permission denied?)" >&2
        rm -f "$temp_file"
        return 1
    fi

    echo "✅ Updated to version $latest_version" >&2
    return 0
}

check_for_updates() {
    local skip_prompt="$1"

    if [ "$DISABLE_UPDATES" = "true" ]; then
        return 0
    fi

    local latest_version
    if ! latest_version=$(get_latest_version); then
        return 0
    fi

    compare_versions "$VERSION" "$latest_version"
    local comparison=$?

    if [ $comparison -eq 1 ]; then
        echo "" >&2
        echo "🆕 A new version of codext is available: $latest_version (current: $VERSION)" >&2

        local release_notes
        if release_notes=$(get_release_notes "$latest_version"); then
            echo "" >&2
            echo "📋 Release notes:" >&2
            echo "─────────────────────────────────────────" >&2
            echo "$release_notes" >&2
            echo "─────────────────────────────────────────" >&2
        fi

        if [ "$skip_prompt" = "true" ]; then
            return 0
        fi

        echo "" >&2
        local response
        if [ "$AUTO_UPDATE" = "true" ]; then
            response="y"
        else
            echo -n "Would you like to update now? [y/N] " >&2
            if ! read -t 60 -r response; then
                echo "" >&2
                echo "⏱️  No response received within 60 seconds, skipping update." >&2
                response="n"
            fi
        fi

        if [[ "$response" =~ ^[Yy]$ ]]; then
            local script_path=$(get_script_path)

            if download_and_install_update "$latest_version" "$script_path"; then
                echo "🔄 Restarting with new version..." >&2
                exec "$script_path" "$@"
            else
                echo "⚠️  Update failed. Continuing with current version." >&2
            fi
        else
            echo "⏭️  Skipping update. You can update later with: codext update" >&2
        fi
    fi

    return 0
}

handle_update_command() {
    if [ "$DISABLE_UPDATES" = "true" ]; then
        echo "⚠️  Updates are disabled via --disable-updates flag. Skipping." >&2
        exit 0
    fi

    echo "🔍 Checking for updates..." >&2

    local latest_version
    if ! latest_version=$(get_latest_version); then
        echo "❌ Failed to check for updates. Make sure 'gh' CLI is installed and authenticated." >&2
        if [ "$UPDATE_REPO_OWNER" = "OWNER_PLACEHOLDER" ]; then
            echo "ℹ️  Note: This build has no upstream repo configured (UPDATE_REPO_OWNER=OWNER_PLACEHOLDER)." >&2
        fi
        exit 1
    fi

    compare_versions "$VERSION" "$latest_version"
    local comparison=$?

    if [ $comparison -eq 0 ]; then
        echo "✅ You're already on the latest version ($VERSION)" >&2
        exit 0
    elif [ $comparison -eq 2 ]; then
        echo "ℹ️  You're on a newer version ($VERSION) than the latest release ($latest_version)" >&2
        exit 0
    fi

    echo "🆕 New version available: $latest_version (current: $VERSION)" >&2

    local release_notes
    if release_notes=$(get_release_notes "$latest_version"); then
        echo "" >&2
        echo "📋 Release notes:" >&2
        echo "─────────────────────────────────────────" >&2
        echo "$release_notes" >&2
        echo "─────────────────────────────────────────" >&2
    fi

    echo "" >&2
    local response
    if [ "$AUTO_UPDATE" = "true" ]; then
        response="y"
    else
        echo -n "Would you like to update now? [y/N] " >&2
        if ! read -t 60 -r response; then
            echo "" >&2
            echo "⏱️  No response received within 60 seconds, skipping update." >&2
            response="n"
        fi
    fi

    if [[ "$response" =~ ^[Yy]$ ]]; then
        local script_path=$(get_script_path)

        if download_and_install_update "$latest_version" "$script_path"; then
            echo "✅ Update complete! Version $latest_version is now installed." >&2
            exit 0
        else
            echo "❌ Update failed." >&2
            exit 1
        fi
    else
        echo "⏭️  Update cancelled." >&2
        exit 0
    fi
}

detect_github_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return 1
    fi

    local remote_url
    if ! remote_url=$(git remote get-url origin 2>/dev/null); then
        return 1
    fi

    local owner=""
    local repo=""

    if [[ "$remote_url" =~ ^https://github\.com/([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    elif [[ "$remote_url" =~ ^git@github\.com:([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    else
        return 1
    fi

    repo="${repo%.git}"

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        return 1
    fi

    echo "$owner $repo"
    return 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -p|--prompt)
                PROMPT="$2"
                shift 2
                ;;
            -m|--max-runs)
                MAX_RUNS="$2"
                shift 2
                ;;
            --max-tokens)
                MAX_TOKENS="$2"
                shift 2
                ;;
            --max-duration)
                MAX_DURATION="$2"
                shift 2
                ;;
            --git-branch-prefix)
                GIT_BRANCH_PREFIX="$2"
                shift 2
                ;;
            --merge-strategy)
                MERGE_STRATEGY="$2"
                shift 2
                ;;
            --owner)
                GITHUB_OWNER="$2"
                shift 2
                ;;
            --repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            --disable-commits)
                ENABLE_COMMITS=false
                shift
                ;;
            --disable-branches)
                DISABLE_BRANCHES=true
                shift
                ;;
            --auto-update)
                AUTO_UPDATE=true
                shift
                ;;
            --disable-updates)
                DISABLE_UPDATES=true
                shift
                ;;
            --notes-file)
                NOTES_FILE="$2"
                shift 2
                ;;
            --worktree)
                WORKTREE_NAME="$2"
                shift 2
                ;;
            --worktree-base-dir)
                WORKTREE_BASE_DIR="$2"
                shift 2
                ;;
            --cleanup-worktree)
                CLEANUP_WORKTREE=true
                shift
                ;;
            --list-worktrees)
                LIST_WORKTREES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --completion-signal)
                COMPLETION_SIGNAL="$2"
                shift 2
                ;;
            --completion-threshold)
                COMPLETION_THRESHOLD="$2"
                shift 2
                ;;
            -r|--review-prompt)
                REVIEW_PROMPT="$2"
                shift 2
                ;;
            --disable-ci-retry)
                CI_RETRY_ENABLED=false
                shift
                ;;
            --ci-retry-max)
                CI_RETRY_MAX_ATTEMPTS="$2"
                shift 2
                ;;
            --disable-comment-review)
                COMMENT_REVIEW_ENABLED=false
                shift
                ;;
            --comment-review-max)
                COMMENT_REVIEW_MAX_ATTEMPTS="$2"
                shift 2
                ;;
            *)
                # Forward unknown flags to `codex exec`. This covers
                # --model, --yolo, --sandbox, --add-dir, -c, etc.
                EXTRA_CODEX_FLAGS+=("$1")
                shift
                ;;
        esac
    done
}

parse_update_flags() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-update)
                AUTO_UPDATE=true
                shift
                ;;
            --disable-updates)
                DISABLE_UPDATES=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "❌ Unknown flag for update command: $1" >&2
                exit 1
                ;;
        esac
    done
}

validate_arguments() {
    if [ -z "$PROMPT" ]; then
        echo "❌ Error: Prompt is required. Use -p to provide a prompt." >&2
        echo "Run '$0 --help' for usage information." >&2
        exit 1
    fi

    if [ -z "$MAX_RUNS" ] && [ -z "$MAX_TOKENS" ] && [ -z "$MAX_DURATION" ]; then
        echo "❌ Error: Either --max-runs, --max-tokens, or --max-duration is required." >&2
        echo "Run '$0 --help' for usage information." >&2
        exit 1
    fi

    if [ -n "$MAX_RUNS" ] && ! [[ "$MAX_RUNS" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-runs must be a non-negative integer" >&2
        exit 1
    fi

    if [ -n "$MAX_TOKENS" ]; then
        if ! [[ "$MAX_TOKENS" =~ ^[0-9]+$ ]] || [ "$MAX_TOKENS" -le 0 ]; then
            echo "❌ Error: --max-tokens must be a positive integer" >&2
            exit 1
        fi
    fi

    if [ -n "$MAX_DURATION" ]; then
        local duration_seconds
        if ! duration_seconds=$(parse_duration "$MAX_DURATION"); then
            echo "❌ Error: --max-duration must be a valid duration (e.g., '2h', '30m', '1h30m', '90s')" >&2
            exit 1
        fi
        MAX_DURATION="$duration_seconds"
    fi

    if [[ ! "$MERGE_STRATEGY" =~ ^(squash|merge|rebase)$ ]]; then
        echo "❌ Error: --merge-strategy must be one of: squash, merge, rebase" >&2
        exit 1
    fi

    if [ -n "$COMPLETION_THRESHOLD" ]; then
        if ! [[ "$COMPLETION_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$COMPLETION_THRESHOLD" -lt 1 ]; then
            echo "❌ Error: --completion-threshold must be a positive integer" >&2
            exit 1
        fi
    fi

    if [ -n "$CI_RETRY_MAX_ATTEMPTS" ]; then
        if ! [[ "$CI_RETRY_MAX_ATTEMPTS" =~ ^[0-9]+$ ]] || [ "$CI_RETRY_MAX_ATTEMPTS" -lt 1 ]; then
            echo "❌ Error: --ci-retry-max must be a positive integer" >&2
            exit 1
        fi
    fi

    if [ -n "$COMMENT_REVIEW_MAX_ATTEMPTS" ]; then
        if ! [[ "$COMMENT_REVIEW_MAX_ATTEMPTS" =~ ^[0-9]+$ ]] || [ "$COMMENT_REVIEW_MAX_ATTEMPTS" -lt 1 ]; then
            echo "❌ Error: --comment-review-max must be a positive integer" >&2
            exit 1
        fi
    fi

    if [ "$ENABLE_COMMITS" = "true" ]; then
        if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
            local detected_info
            if detected_info=$(detect_github_repo); then
                local detected_owner=$(echo "$detected_info" | awk '{print $1}')
                local detected_repo=$(echo "$detected_info" | awk '{print $2}')

                if [ -z "$GITHUB_OWNER" ]; then
                    GITHUB_OWNER="$detected_owner"
                fi
                if [ -z "$GITHUB_REPO" ]; then
                    GITHUB_REPO="$detected_repo"
                fi
            fi
        fi

        if [ -z "$GITHUB_OWNER" ]; then
            echo "❌ Error: GitHub owner is required. Use --owner to provide the owner, or run from a git repository with a GitHub remote." >&2
            echo "Run '$0 --help' for usage information." >&2
            exit 1
        fi

        if [ -z "$GITHUB_REPO" ]; then
            echo "❌ Error: GitHub repo is required. Use --repo to provide the repo, or run from a git repository with a GitHub remote." >&2
            echo "Run '$0 --help' for usage information." >&2
            exit 1
        fi
    fi
}

validate_requirements() {
    if ! command -v codex &> /dev/null; then
        echo "❌ Error: Codex CLI is not installed. Install from: https://github.com/openai/codex" >&2
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "⚠️ jq is required for JSON parsing but is not installed. Asking Codex CLI to install it..." >&2
        codex exec --full-auto --skip-git-repo-check "$PROMPT_JQ_INSTALL" >/dev/null 2>&1 || true
        if ! command -v jq &> /dev/null; then
            echo "❌ Error: jq is still not installed after Codex CLI attempt." >&2
            exit 1
        fi
    fi

    if [ "$ENABLE_COMMITS" = "true" ]; then
        if ! command -v gh &> /dev/null; then
            echo "❌ Error: GitHub CLI (gh) is not installed: https://cli.github.com" >&2
            exit 1
        fi

        if ! gh auth status >/dev/null 2>&1; then
            echo "❌ Error: GitHub CLI is not authenticated. Run 'gh auth login' first." >&2
            exit 1
        fi
    fi
}

wait_for_pr_checks() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local iteration_display="$4"
    local max_iterations=180  # 180 * 10 seconds = 30 minutes
    local iteration=0

    local prev_check_count=""
    local prev_success_count=""
    local prev_pending_count=""
    local prev_failed_count=""
    local prev_review_status=""
    local prev_no_checks_configured=""
    local waiting_message_printed=false

    while [ $iteration -lt $max_iterations ]; do
        local checks_json
        local no_checks_configured=false
        if ! checks_json=$(gh pr checks "$pr_number" --repo "$owner/$repo" --json state,bucket 2>&1); then
            if echo "$checks_json" | grep -q "no checks"; then
                no_checks_configured=true
                checks_json="[]"
            else
                echo "⚠️  $iteration_display Failed to get PR checks status: $checks_json" >&2
                return 1
            fi
        fi

        local check_count=$(echo "$checks_json" | jq 'length' 2>/dev/null || echo "0")

        local all_completed=true
        local all_success=true

        if [ "$no_checks_configured" = "false" ] && [ "$check_count" -eq 0 ]; then
            all_completed=false
        fi

        local pending_count=0
        local success_count=0
        local failed_count=0

        if [ "$check_count" -gt 0 ]; then
            local idx=0
            while [ $idx -lt $check_count ]; do
                local state=$(echo "$checks_json" | jq -r ".[$idx].state")
                local bucket=$(echo "$checks_json" | jq -r ".[$idx].bucket // \"pending\"")

                if [ "$bucket" = "pending" ] || [ "$bucket" = "null" ]; then
                    all_completed=false
                    pending_count=$((pending_count + 1))
                elif [ "$bucket" = "fail" ]; then
                    all_success=false
                    failed_count=$((failed_count + 1))
                else
                    success_count=$((success_count + 1))
                fi

                idx=$((idx + 1))
            done
        fi

        local pr_info
        if ! pr_info=$(gh pr view "$pr_number" --repo "$owner/$repo" --json reviewDecision,reviewRequests 2>&1); then
            echo "⚠️  $iteration_display Failed to get PR review status: $pr_info" >&2
            return 1
        fi

        local review_decision=$(echo "$pr_info" | jq -r 'if .reviewDecision == "" then "null" else (.reviewDecision // "null") end')
        local review_requests_count=$(echo "$pr_info" | jq '.reviewRequests | length' 2>/dev/null || echo "0")

        local reviews_pending=false
        if [ "$review_decision" = "REVIEW_REQUIRED" ] || [ "$review_requests_count" -gt 0 ]; then
            reviews_pending=true
        fi

        local review_status="None"
        if [ -n "$review_decision" ] && [ "$review_decision" != "null" ]; then
            review_status="$review_decision"
        elif [ "$review_requests_count" -gt 0 ]; then
            review_status="$review_requests_count review(s) requested"
        fi

        local state_changed=false
        if [ "$check_count" != "$prev_check_count" ] || \
           [ "$success_count" != "$prev_success_count" ] || \
           [ "$pending_count" != "$prev_pending_count" ] || \
           [ "$failed_count" != "$prev_failed_count" ] || \
           [ "$review_status" != "$prev_review_status" ] || \
           [ "$no_checks_configured" != "$prev_no_checks_configured" ] || \
           [ -z "$prev_check_count" ]; then
            state_changed=true
        fi

        if [ "$state_changed" = "true" ]; then
            echo "" >&2
            echo "🔍 $iteration_display Checking PR status (iteration $((iteration + 1))/$max_iterations)..." >&2

            if [ "$no_checks_configured" = "true" ]; then
                echo "   📊 No checks configured" >&2
            else
                echo "   📊 Found $check_count check(s)" >&2
            fi

            if [ "$check_count" -gt 0 ]; then
                echo "   🟢 $success_count    🟡 $pending_count    🔴 $failed_count" >&2
            fi

            echo "   👁️  Review status: $review_status" >&2

            prev_check_count="$check_count"
            prev_success_count="$success_count"
            prev_pending_count="$pending_count"
            prev_failed_count="$failed_count"
            prev_review_status="$review_status"
            prev_no_checks_configured="$no_checks_configured"
        fi

        if [ "$check_count" -eq 0 ] && [ "$checks_json" = "[]" ] && [ "$no_checks_configured" = "false" ]; then
            if [ "$iteration" -lt 18 ]; then
                if [ "$waiting_message_printed" = "false" ]; then
                    echo -n "⏳ Waiting for checks to start... (will timeout after 3 minutes) " >&2
                    waiting_message_printed=true
                fi
                echo -n "." >&2
                sleep 10
                iteration=$((iteration + 1))
                continue
            else
                echo "" >&2
                echo "   ⚠️  No checks found after waiting, proceeding without checks" >&2
                all_completed=true
                all_success=true
            fi
        else
            if [ "$waiting_message_printed" = "true" ]; then
                echo "" >&2
            fi
            waiting_message_printed=false
        fi

        if [ "$all_completed" = "true" ] && [ "$all_success" = "true" ] && [ "$reviews_pending" = "false" ]; then
            if [ "$review_decision" = "APPROVED" ]; then
                echo "✅ $iteration_display All PR checks and reviews passed" >&2
                return 0
            elif { [ "$review_decision" = "null" ] || [ -z "$review_decision" ]; } && [ "$review_requests_count" -eq 0 ]; then
                echo "✅ $iteration_display All PR checks and reviews passed" >&2
                return 0
            fi
        fi

        if [ "$all_completed" = "true" ] && [ "$all_success" = "true" ] && [ "$reviews_pending" = "true" ]; then
            if [ "$state_changed" = "true" ]; then
                echo "   ✅ All checks passed, but waiting for review..." >&2
            fi
        fi

        if [ "$all_completed" = "true" ] && [ "$all_success" = "false" ]; then
            echo "❌ $iteration_display PR checks failed" >&2
            return 1
        fi

        if [ "$review_decision" = "CHANGES_REQUESTED" ]; then
            echo "❌ $iteration_display PR has changes requested in review" >&2
            return 1
        fi

        local waiting_items=()

        if [ "$all_completed" = "false" ]; then
            waiting_items+=("checks to complete")
        fi

        if [ "$reviews_pending" = "true" ]; then
            waiting_items+=("code review")
        fi

        if [ ${#waiting_items[@]} -gt 0 ] && [ "$state_changed" = "true" ]; then
            echo "⏳ Waiting for: ${waiting_items[*]}" >&2
        fi

        sleep 10
        iteration=$((iteration + 1))
    done

    echo "⏱️  $iteration_display Timeout waiting for PR checks and reviews (30 minutes)" >&2
    return 1
}

check_pr_comments() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local iteration_display="$4"
    local since="$5"

    local review_comments issue_comments

    if [ -n "$since" ]; then
        review_comments=$(gh api "repos/$owner/$repo/pulls/$pr_number/comments" --jq "[.[] | select(.created_at > \"$since\")] | length" 2>/dev/null || echo "0")
        issue_comments=$(gh api "repos/$owner/$repo/issues/$pr_number/comments?since=$since" --jq 'length' 2>/dev/null || echo "0")
    else
        review_comments=$(gh api "repos/$owner/$repo/pulls/$pr_number/comments" --jq 'length' 2>/dev/null || echo "0")
        issue_comments=$(gh api "repos/$owner/$repo/issues/$pr_number/comments" --jq 'length' 2>/dev/null || echo "0")
    fi

    local total_comments=$((review_comments + issue_comments))

    if [ "$total_comments" -gt 0 ]; then
        echo "💬 $iteration_display Found $total_comments comment(s) on PR #$pr_number ($review_comments inline, $issue_comments general)" >&2
        return 0
    fi

    echo "✅ $iteration_display No comments found on PR #$pr_number" >&2
    return 1
}

get_failed_run_id() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"

    local head_sha
    head_sha=$(gh pr view "$pr_number" --repo "$owner/$repo" --json headRefOid --jq '.headRefOid' 2>/dev/null)

    if [ -z "$head_sha" ]; then
        return 1
    fi

    local run_id
    run_id=$(gh run list --repo "$owner/$repo" --commit "$head_sha" --status failure --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)

    if [ -z "$run_id" ] || [ "$run_id" = "null" ]; then
        return 1
    fi

    echo "$run_id"
    return 0
}

merge_pr_and_cleanup() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local branch_name="$4"
    local iteration_display="$5"
    local current_branch="$6"

    echo "🔄 $iteration_display Updating branch with latest from main..." >&2
    local update_output
    if update_output=$(gh pr update-branch "$pr_number" --repo "$owner/$repo" 2>&1); then
        echo "📥 $iteration_display Branch updated, re-checking PR status..." >&2
        if ! wait_for_pr_checks "$pr_number" "$owner" "$repo" "$iteration_display"; then
            echo "❌ $iteration_display PR checks failed after branch update" >&2
            return 1
        fi
    else
        if echo "$update_output" | grep -qi "already up-to-date\|is up to date"; then
            echo "✅ $iteration_display Branch already up-to-date" >&2
        else
            echo "⚠️  $iteration_display Branch update failed: $update_output" >&2
            return 1
        fi
    fi

    local merge_flag=""
    case "$MERGE_STRATEGY" in
        squash)
            merge_flag="--squash"
            ;;
        merge)
            merge_flag="--merge"
            ;;
        rebase)
            merge_flag="--rebase"
            ;;
    esac

    echo "🔀 $iteration_display Merging PR #$pr_number with strategy: $MERGE_STRATEGY..." >&2
    if ! gh pr merge "$pr_number" --repo "$owner/$repo" $merge_flag >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to merge PR (may have conflicts or be blocked)" >&2
        return 1
    fi

    echo "📥 $iteration_display Pulling latest from main..." >&2
    if ! git checkout "$current_branch" >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to checkout $current_branch" >&2
        return 1
    fi

    if ! git pull origin "$current_branch" >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to pull from $current_branch" >&2
        return 1
    fi

    echo "🗑️  $iteration_display Deleting local branch: $branch_name" >&2
    git branch -d "$branch_name" >/dev/null 2>&1 || true

    return 0
}

create_iteration_branch() {
    local iteration_display="$1"
    local iteration_num="$2"

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo ""
        return 0
    fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

    if [[ "$current_branch" == ${GIT_BRANCH_PREFIX}* ]]; then
        echo "⚠️  $iteration_display Already on iteration branch: $current_branch" >&2
        git checkout main >/dev/null 2>&1 || return 1
        current_branch="main"
    fi

    local date_str=$(date +%Y-%m-%d)

    local random_hash
    if command -v openssl >/dev/null 2>&1; then
        random_hash=$(openssl rand -hex 4)
    elif [ -r /dev/urandom ]; then
        random_hash=$(LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 8)
    else
        random_hash=$(printf "%x" $(($(date +%s) % 100000000)))$(printf "%x" $$)
        random_hash=${random_hash:0:8}
    fi

    local branch_name="${GIT_BRANCH_PREFIX}iteration-${iteration_num}/${date_str}-${random_hash}"

    echo "🌿 $iteration_display Creating branch: $branch_name" >&2

    if [ "$DRY_RUN" = "true" ]; then
        echo "   (DRY RUN) Would create branch $branch_name" >&2
        echo "$branch_name"
        return 0
    fi

    if ! git checkout -b "$branch_name" >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to create branch" >&2
        echo ""
        return 1
    fi

    echo "$branch_name"
    return 0
}

codext_commit() {
    local iteration_display="$1"
    local branch_name="$2"
    local main_branch="$3"

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    fi

    local has_changes=false
    if ! git diff --quiet --ignore-submodules=dirty || ! git diff --cached --quiet --ignore-submodules=dirty; then
        has_changes=true
    fi

    if [ -z "$(git ls-files --others --exclude-standard)" ]; then
        : # no untracked files
    else
        has_changes=true
    fi

    if [ "$has_changes" = "false" ]; then
        echo "🫙 $iteration_display No changes detected, cleaning up branch..." >&2
        git checkout "$main_branch" >/dev/null 2>&1
        git branch -D "$branch_name" >/dev/null 2>&1 || true
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "💬 $iteration_display (DRY RUN) Would commit changes..." >&2
        echo "📦 $iteration_display (DRY RUN) Changes committed on branch: $branch_name" >&2
        echo "📤 $iteration_display (DRY RUN) Would push branch..." >&2
        echo "🔨 $iteration_display (DRY RUN) Would create pull request..." >&2
        echo "✅ $iteration_display (DRY RUN) PR merged: <commit title would appear here>" >&2
        return 0
    fi

    echo "💬 $iteration_display Committing changes..." >&2

    if ! codex exec --full-auto --skip-git-repo-check "$PROMPT_COMMIT_MESSAGE" >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to commit changes" >&2
        git checkout "$main_branch" >/dev/null 2>&1
        return 1
    fi

    if ! git diff --quiet --ignore-submodules=dirty || ! git diff --cached --quiet --ignore-submodules=dirty || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "⚠️  $iteration_display Commit command ran but changes still present (uncommitted or untracked files remain)" >&2
        git checkout "$main_branch" >/dev/null 2>&1
        return 1
    fi

    echo "📦 $iteration_display Changes committed on branch: $branch_name" >&2

    local commit_message=$(git log -1 --format="%B" "$branch_name")
    local commit_title=$(echo "$commit_message" | head -n 1)
    local commit_body=$(echo "$commit_message" | tail -n +4)

    echo "📤 $iteration_display Pushing branch..." >&2
    if ! git push -u origin "$branch_name" >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to push branch" >&2
        git checkout "$main_branch" >/dev/null 2>&1
        return 1
    fi

    echo "🔨 $iteration_display Creating pull request..." >&2
    local pr_output
    if ! pr_output=$(gh pr create --repo "$GITHUB_OWNER/$GITHUB_REPO" --title "$commit_title" --body "$commit_body" --base "$main_branch" 2>&1); then
        echo "⚠️  $iteration_display Failed to create PR: $pr_output" >&2
        git checkout "$main_branch" >/dev/null 2>&1
        return 1
    fi

    local pr_number=$(echo "$pr_output" | grep -oE '(pull/|#)[0-9]+' | grep -oE '[0-9]+' | head -n 1)
    if [ -z "$pr_number" ]; then
        echo "⚠️  $iteration_display Failed to extract PR number from: $pr_output" >&2
        git checkout "$main_branch" >/dev/null 2>&1
        return 1
    fi

    echo "🔍 $iteration_display PR #$pr_number created, waiting 5 seconds for GitHub to set up..." >&2
    sleep 5
    if ! wait_for_pr_checks "$pr_number" "$GITHUB_OWNER" "$GITHUB_REPO" "$iteration_display"; then
        if [ "$CI_RETRY_ENABLED" = "true" ]; then
            echo "🔧 $iteration_display CI checks failed, attempting automatic fix..." >&2
            if attempt_ci_fix_and_recheck "$pr_number" "$GITHUB_OWNER" "$GITHUB_REPO" "$branch_name" "$iteration_display" "$main_branch" "$ERROR_LOG"; then
                echo "🎉 $iteration_display CI fix successful!" >&2
            else
                echo "⚠️  $iteration_display CI fix unsuccessful, closing PR and deleting remote branch..." >&2
                gh pr close "$pr_number" --repo "$GITHUB_OWNER/$GITHUB_REPO" --delete-branch >/dev/null 2>&1 || true
                echo "🗑️  $iteration_display Cleaning up local branch: $branch_name" >&2
                git checkout "$main_branch" >/dev/null 2>&1
                git branch -D "$branch_name" >/dev/null 2>&1 || true
                return 1
            fi
        else
            echo "⚠️  $iteration_display PR checks failed or timed out, closing PR and deleting remote branch..." >&2
            gh pr close "$pr_number" --repo "$GITHUB_OWNER/$GITHUB_REPO" --delete-branch >/dev/null 2>&1 || true
            echo "🗑️  $iteration_display Cleaning up local branch: $branch_name" >&2
            git checkout "$main_branch" >/dev/null 2>&1
            git branch -D "$branch_name" >/dev/null 2>&1 || true
            return 1
        fi
    fi

    if [ "$COMMENT_REVIEW_ENABLED" = "true" ]; then
        if check_pr_comments "$pr_number" "$GITHUB_OWNER" "$GITHUB_REPO" "$iteration_display"; then
            echo "💬 $iteration_display PR has review comments, attempting to address them..." >&2
            if ! attempt_comment_fix_and_recheck "$pr_number" "$GITHUB_OWNER" "$GITHUB_REPO" "$branch_name" "$iteration_display" "$main_branch" "$ERROR_LOG"; then
                echo "⚠️  $iteration_display Failed to address PR comments, closing PR..." >&2
                gh pr close "$pr_number" --repo "$GITHUB_OWNER/$GITHUB_REPO" --delete-branch >/dev/null 2>&1 || true
                echo "🗑️  $iteration_display Cleaning up local branch: $branch_name" >&2
                git checkout "$main_branch" >/dev/null 2>&1
                git branch -D "$branch_name" >/dev/null 2>&1 || true
                return 1
            fi
        fi
    fi

    if ! merge_pr_and_cleanup "$pr_number" "$GITHUB_OWNER" "$GITHUB_REPO" "$branch_name" "$iteration_display" "$main_branch"; then
        local pr_state=$(gh pr view "$pr_number" --repo "$GITHUB_OWNER/$GITHUB_REPO" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
        if [ "$pr_state" = "OPEN" ]; then
            echo "⚠️  $iteration_display Failed to merge PR, closing it and deleting remote branch..." >&2
            gh pr close "$pr_number" --repo "$GITHUB_OWNER/$GITHUB_REPO" --delete-branch >/dev/null 2>&1 || true
        else
            echo "⚠️  $iteration_display PR was merged but cleanup failed" >&2
        fi
        echo "🗑️  $iteration_display Cleaning up local branch: $branch_name" >&2
        git checkout "$main_branch" >/dev/null 2>&1
        git branch -D "$branch_name" >/dev/null 2>&1 || true
        return 1
    fi

    echo "✅ $iteration_display PR #$pr_number merged: $commit_title" >&2

    if ! git checkout "$main_branch" >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to checkout $main_branch" >&2
        return 1
    fi

    return 0
}

commit_on_current_branch() {
    local iteration_display="$1"

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    fi

    local has_changes=false
    if ! git diff --quiet --ignore-submodules=dirty || ! git diff --cached --quiet --ignore-submodules=dirty; then
        has_changes=true
    fi

    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        has_changes=true
    fi

    if [ "$has_changes" = "false" ]; then
        echo "ℹ️  $iteration_display No changes to commit" >&2
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "💬 $iteration_display (DRY RUN) Would commit changes on current branch..." >&2
        return 0
    fi

    echo "💬 $iteration_display Committing changes on current branch..." >&2

    if ! codex exec --full-auto --skip-git-repo-check "$PROMPT_COMMIT_MESSAGE" >/dev/null 2>&1; then
        echo "⚠️  $iteration_display Failed to commit changes" >&2
        return 1
    fi

    if ! git diff --quiet --ignore-submodules=dirty || ! git diff --cached --quiet --ignore-submodules=dirty || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "⚠️  $iteration_display Commit command ran but changes still present" >&2
        return 1
    fi

    local commit_title=$(git log -1 --format="%s")
    echo "✅ $iteration_display Committed: $commit_title" >&2
    return 0
}

list_worktrees() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Error: Not in a git repository" >&2
        exit 1
    fi

    echo "📋 Active Git Worktrees:"
    echo ""

    if ! git worktree list 2>/dev/null; then
        echo "❌ Error: Failed to list worktrees" >&2
        exit 1
    fi

    exit 0
}

setup_worktree() {
    if [ -z "$WORKTREE_NAME" ]; then
        return 0
    fi

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Error: Not in a git repository. Worktrees require a git repository." >&2
        exit 1
    fi

    local main_repo_dir=$(git rev-parse --show-toplevel)
    local worktree_path="${WORKTREE_BASE_DIR}/${WORKTREE_NAME}"

    if [[ "$worktree_path" != /* ]]; then
        worktree_path="${main_repo_dir}/${worktree_path}"
    fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

    if [ -d "$worktree_path" ]; then
        echo "🌿 Worktree '$WORKTREE_NAME' already exists at: $worktree_path" >&2
        echo "📂 Switching to worktree directory..." >&2

        if ! cd "$worktree_path"; then
            echo "❌ Error: Failed to change to worktree directory: $worktree_path" >&2
            exit 1
        fi

        echo "📥 Pulling latest changes from $current_branch..." >&2
        if ! git pull origin "$current_branch" >/dev/null 2>&1; then
            echo "⚠️  Warning: Failed to pull latest changes (continuing anyway)" >&2
        fi
    else
        echo "🌿 Creating new worktree '$WORKTREE_NAME' at: $worktree_path" >&2

        local base_dir=$(dirname "$worktree_path")
        if [ ! -d "$base_dir" ]; then
            mkdir -p "$base_dir" || {
                echo "❌ Error: Failed to create worktree base directory: $base_dir" >&2
                exit 1
            }
        fi

        if ! git worktree add "$worktree_path" "$current_branch" 2>&1; then
            echo "❌ Error: Failed to create worktree" >&2
            exit 1
        fi

        echo "📂 Switching to worktree directory..." >&2
        if ! cd "$worktree_path"; then
            echo "❌ Error: Failed to change to worktree directory: $worktree_path" >&2
            exit 1
        fi
    fi

    echo "✅ Worktree '$WORKTREE_NAME' ready at: $worktree_path" >&2
    return 0
}

cleanup_worktree() {
    if [ -z "$WORKTREE_NAME" ] || [ "$CLEANUP_WORKTREE" = "false" ]; then
        return 0
    fi

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    fi

    local worktree_path="${WORKTREE_BASE_DIR}/${WORKTREE_NAME}"

    local main_repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$main_repo_dir" ]; then
        if [[ "$worktree_path" != /* ]]; then
            worktree_path="${main_repo_dir}/${worktree_path}"
        fi
    fi

    echo "" >&2
    echo "🗑️  Cleaning up worktree '$WORKTREE_NAME'..." >&2

    local git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    if [ -n "$git_common_dir" ]; then
        local main_repo=$(dirname "$git_common_dir")
        if [ -d "$main_repo" ]; then
            cd "$main_repo" 2>/dev/null || true
        fi
    fi

    if git worktree remove "$worktree_path" --force 2>/dev/null; then
        echo "✅ Worktree removed successfully" >&2
    else
        echo "⚠️  Warning: Failed to remove worktree (may need manual cleanup)" >&2
        echo "   You can manually remove it with: git worktree remove $worktree_path --force" >&2
    fi
}

get_iteration_display() {
    local iteration_num=$1
    local max_runs=$2
    local extra_iters=$3

    if [ $max_runs -eq 0 ]; then
        echo "($iteration_num)"
    else
        local total=$((max_runs + extra_iters))
        echo "($iteration_num/$total)"
    fi
}

# Run a single `codex exec` invocation, streaming the JSONL event flow to a
# human-readable form on stderr while writing the raw JSONL to stdout for the
# caller. The caller is expected to extract per-iteration token usage from
# turn.completed events in the captured stdout.
#
# Codex JSONL events of interest:
#   {"type":"thread.started","thread_id":"..."}
#   {"type":"turn.started"}
#   {"type":"turn.completed","usage":{"input_tokens":N,"cached_input_tokens":N,"output_tokens":N,"reasoning_output_tokens":N}}
#   {"type":"turn.failed","error":{"message":"..."}}
#   {"type":"item.started","item":{"id":"item_X","type":"command_execution|file_change|web_search|mcp_tool_call|reasoning|agent_message", ...}}
#   {"type":"item.completed","item":{...}}
#   {"type":"error","message":"..."}
run_codex_iteration() {
    local prompt="$1"
    local flags="$2"
    local error_log="$3"
    local iteration_display="$4"

    if [ "$DRY_RUN" = "true" ]; then
        echo "🤖 (DRY RUN) Would run Codex CLI with prompt: $prompt" >&2
        # Emit a synthetic JSONL stream that downstream parsers accept.
        printf '{"type":"thread.started","thread_id":"dry-run"}\n{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"This is a simulated response from Codex CLI."}}\n{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0}}\n'
        echo "(DRY RUN) Codex CLI was not invoked." > "$error_log"
        return 0
    fi

    local temp_stdout=$(mktemp)
    local temp_stderr=$(mktemp)
    local exit_code=0

    set -o pipefail
    codex exec $flags "${EXTRA_CODEX_FLAGS[@]}" "$prompt" 2> >(tee "$temp_stderr" >&2) | \
        tee "$temp_stdout" | \
        while IFS= read -r line; do
            # Skip empty lines or non-JSON lines defensively.
            [ -z "$line" ] && continue

            # Extract a human-friendly display string with a leading emoji.
            # Returns empty string when the event is one we don't render.
            local display
            display=$(echo "$line" | jq -r --arg pwd "$PWD" '
                def relpath: (if startswith($pwd + "/") then .[$pwd | length + 1:] elif . == $pwd then "." else . end) // .;
                def truncate: if length > 240 then .[0:240] + "..." else . end;
                def fmt_command:
                    if (type == "array") then (. | join(" ")) else (. // "" | tostring) end;
                if .type == "item.completed" and .item.type == "agent_message" then
                    "💬 " + ((.item.text // "") | gsub("\n+$"; "") | truncate)
                elif .type == "item.started" and .item.type == "command_execution" then
                    "💻 " + ((.item.command // "") | fmt_command | split("\n")[0] | truncate)
                elif .type == "item.completed" and .item.type == "file_change" then
                    ("✏️ " + ((.item.changes // []) | map((.kind // "?") + " " + ((.path // "") | relpath)) | join(", ")) | truncate)
                elif .type == "item.started" and .item.type == "web_search" then
                    "🔍 \"" + ((.item.query // "") | truncate) + "\""
                elif .type == "item.started" and .item.type == "mcp_tool_call" then
                    "🔌 " + ((.item.server // "?") + "/" + (.item.tool // "?"))
                elif .type == "item.completed" and .item.type == "patch_apply" then
                    "🩹 patch " + (.item.status // "?")
                elif .type == "turn.failed" then
                    "❌ " + ((.error.message // "turn failed") | truncate)
                else
                    # Skip standalone "error" events in the streaming display:
                    # codex usually pairs them with a turn.failed that carries
                    # the same message. parse_codex_result still picks up
                    # standalone errors and surfaces them after the iteration.
                    empty
                end
            ' 2>/dev/null)

            if [ -n "$display" ]; then
                echo "$display" | while IFS= read -r out_line; do
                    printf "   %s %s\n" "$iteration_display" "$out_line" >&2
                done
            fi
        done
    exit_code=${PIPESTATUS[0]}
    set +o pipefail

    wait

    if [ -f "$temp_stdout" ] && [ -s "$temp_stdout" ]; then
        cat "$temp_stdout"
    fi

    if [ -f "$temp_stderr" ] && [ -s "$temp_stderr" ]; then
        cat "$temp_stderr" > "$error_log"
    fi

    if [ $exit_code -ne 0 ]; then
        if [ ! -s "$error_log" ] && [ -f "$temp_stdout" ] && [ -s "$temp_stdout" ]; then
            local json_error
            json_error=$(jq -s -r '
                map(select(.type == "turn.failed" or .type == "error")) |
                if length > 0 then
                    (last | (.error.message // .message // "Unknown error"))
                else
                    empty
                end
            ' "$temp_stdout" 2>/dev/null || echo "")
            if [ -n "$json_error" ]; then
                echo "$json_error" > "$error_log"
                echo "$json_error" >&2
            fi
        fi

        if [ ! -s "$error_log" ]; then
            {
                echo "Codex CLI exited with code $exit_code but produced no error output"
                echo ""
                echo "This usually means:"
                echo "  - Codex CLI crashed or failed to start"
                echo "  - An authentication issue (try: codex login status)"
                echo "  - The command arguments are invalid"
                echo ""
                echo "Try running this command directly to see the full error:"
                echo "  codex exec $flags ${EXTRA_CODEX_FLAGS[*]} \"$prompt\""
            } >> "$error_log"
        fi

        rm -f "$temp_stdout" "$temp_stderr"
        return $exit_code
    fi

    rm -f "$temp_stdout" "$temp_stderr"
    return 0
}

# Per-iteration token counts written by accumulate_iteration_tokens.
# These are read by callers immediately after the call. Globals (rather
# than a stdout return value) are required because callers must run the
# function in the current shell — `var=$(accumulate_iteration_tokens ...)`
# would put it in a subshell and the running totals would never accumulate.
LAST_ITER_INPUT_TOKENS=0
LAST_ITER_OUTPUT_TOKENS=0
LAST_ITER_REASONING_TOKENS=0
LAST_ITER_CACHED_INPUT_TOKENS=0
LAST_ITER_TOKEN_TOTAL=0

# Sum token usage across all turn.completed events in the iteration's
# captured JSONL output. Updates the running totals AND the LAST_ITER_*
# globals so the caller can log the per-iteration breakdown without
# re-parsing the JSONL.
accumulate_iteration_tokens() {
    local result="$1"

    LAST_ITER_INPUT_TOKENS=$(echo "$result" | jq -s '[.[] | select(.type == "turn.completed") | .usage.input_tokens // 0] | add // 0' 2>/dev/null || echo "0")
    LAST_ITER_OUTPUT_TOKENS=$(echo "$result" | jq -s '[.[] | select(.type == "turn.completed") | .usage.output_tokens // 0] | add // 0' 2>/dev/null || echo "0")
    LAST_ITER_REASONING_TOKENS=$(echo "$result" | jq -s '[.[] | select(.type == "turn.completed") | .usage.reasoning_output_tokens // 0] | add // 0' 2>/dev/null || echo "0")
    LAST_ITER_CACHED_INPUT_TOKENS=$(echo "$result" | jq -s '[.[] | select(.type == "turn.completed") | .usage.cached_input_tokens // 0] | add // 0' 2>/dev/null || echo "0")

    total_input_tokens=$((total_input_tokens + LAST_ITER_INPUT_TOKENS))
    total_output_tokens=$((total_output_tokens + LAST_ITER_OUTPUT_TOKENS))
    total_reasoning_tokens=$((total_reasoning_tokens + LAST_ITER_REASONING_TOKENS))
    total_cached_input_tokens=$((total_cached_input_tokens + LAST_ITER_CACHED_INPUT_TOKENS))

    LAST_ITER_TOKEN_TOTAL=$((LAST_ITER_INPUT_TOKENS + LAST_ITER_OUTPUT_TOKENS + LAST_ITER_REASONING_TOKENS))
}

run_reviewer_iteration() {
    local iteration_display="$1"
    local review_prompt="$2"
    local error_log="$3"

    echo "🔍 $iteration_display Running reviewer pass..." >&2

    local full_reviewer_prompt="${PROMPT_REVIEWER_CONTEXT}

## USER REVIEW INSTRUCTIONS

${review_prompt}"

    local result
    local codex_exit_code=0
    result=$(run_codex_iteration "$full_reviewer_prompt" "$ADDITIONAL_FLAGS" "$error_log" "$iteration_display") || codex_exit_code=$?

    if [ $codex_exit_code -ne 0 ]; then
        echo "❌ $iteration_display Reviewer pass failed with exit code: $codex_exit_code" >&2
        return 1
    fi

    local parse_result=$(parse_codex_result "$result")
    if [ "$?" != "0" ]; then
        echo "❌ $iteration_display Reviewer pass returned error: $parse_result" >&2
        return 1
    fi

    accumulate_iteration_tokens "$result"
    if [ "$LAST_ITER_TOKEN_TOTAL" != "0" ]; then
        printf "🔢 %s Reviewer tokens: %s (running total: %s)\n" "$iteration_display" "$(format_tokens "$LAST_ITER_TOKEN_TOTAL")" "$(format_tokens $((total_input_tokens + total_output_tokens + total_reasoning_tokens)))" >&2
    fi

    echo "✅ $iteration_display Reviewer pass completed" >&2
    return 0
}

run_ci_fix_iteration() {
    local iteration_display="$1"
    local pr_number="$2"
    local owner="$3"
    local repo="$4"
    local branch_name="$5"
    local error_log="$6"
    local retry_attempt="$7"

    echo "🔧 $iteration_display Attempting to fix CI failure (attempt $retry_attempt/$CI_RETRY_MAX_ATTEMPTS)..." >&2

    local failed_run_id
    failed_run_id=$(get_failed_run_id "$pr_number" "$owner" "$repo")

    local ci_fix_prompt="${PROMPT_CI_FIX_CONTEXT}

## CURRENT CONTEXT

- Repository: $owner/$repo
- PR Number: #$pr_number
- Branch: $branch_name"

    if [ -n "$failed_run_id" ]; then
        ci_fix_prompt+="
- Failed Run ID: $failed_run_id (use this with \`gh run view $failed_run_id --log-failed\`)"
    fi

    ci_fix_prompt+="

## INSTRUCTIONS

1. Start by running \`gh run list --status failure --limit 3\` to see recent failures
2. Then use \`gh run view <RUN_ID> --log-failed\` to see the error details
3. Analyze what went wrong and fix it
4. After making changes, stage, commit, AND PUSH them with a clear commit message describing the fix
5. You MUST push the changes to trigger a new CI run"

    local result
    local codex_exit_code=0
    result=$(run_codex_iteration "$ci_fix_prompt" "$ADDITIONAL_FLAGS" "$error_log" "$iteration_display") || codex_exit_code=$?

    if [ $codex_exit_code -ne 0 ]; then
        echo "❌ $iteration_display CI fix attempt failed with exit code: $codex_exit_code" >&2
        return 1
    fi

    local parse_result=$(parse_codex_result "$result")
    if [ "$?" != "0" ]; then
        echo "❌ $iteration_display CI fix returned error: $parse_result" >&2
        return 1
    fi

    accumulate_iteration_tokens "$result"
    if [ "$LAST_ITER_TOKEN_TOTAL" != "0" ]; then
        printf "🔢 %s CI fix tokens: %s (running total: %s)\n" "$iteration_display" "$(format_tokens "$LAST_ITER_TOKEN_TOTAL")" "$(format_tokens $((total_input_tokens + total_output_tokens + total_reasoning_tokens)))" >&2
    fi

    echo "✅ $iteration_display CI fix iteration completed, checking CI status..." >&2
    return 0
}

attempt_ci_fix_and_recheck() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local branch_name="$4"
    local iteration_display="$5"
    local main_branch="$6"
    local error_log="$7"

    local retry_attempt=1

    while [ $retry_attempt -le $CI_RETRY_MAX_ATTEMPTS ]; do
        if ! run_ci_fix_iteration "$iteration_display" "$pr_number" "$owner" "$repo" "$branch_name" "$error_log" "$retry_attempt"; then
            echo "⚠️  $iteration_display CI fix attempt $retry_attempt failed" >&2
            retry_attempt=$((retry_attempt + 1))
            continue
        fi

        sleep 5

        echo "🔍 $iteration_display Waiting for CI checks after fix..." >&2
        if wait_for_pr_checks "$pr_number" "$owner" "$repo" "$iteration_display"; then
            echo "✅ $iteration_display CI checks passed after fix!" >&2
            return 0
        fi

        echo "⚠️  $iteration_display CI still failing after fix attempt $retry_attempt" >&2
        retry_attempt=$((retry_attempt + 1))
    done

    echo "❌ $iteration_display All CI fix attempts exhausted" >&2
    return 1
}

run_comment_fix_iteration() {
    local iteration_display="$1"
    local pr_number="$2"
    local owner="$3"
    local repo="$4"
    local branch_name="$5"
    local error_log="$6"
    local retry_attempt="$7"

    echo "💬 $iteration_display Attempting to address PR comments (attempt $retry_attempt/$COMMENT_REVIEW_MAX_ATTEMPTS)..." >&2

    local comment_review_prompt="${PROMPT_COMMENT_REVIEW_CONTEXT}

## CURRENT CONTEXT

- Repository: $owner/$repo
- PR Number: #$pr_number
- Branch: $branch_name

## INSTRUCTIONS

1. Start by reading inline review comments: \`gh api repos/$owner/$repo/pulls/$pr_number/comments\`
2. Also read PR-level comments: \`gh api repos/$owner/$repo/issues/$pr_number/comments\`
3. Analyze each comment and determine what code changes are needed
4. Make the necessary changes to address the feedback
5. After making changes, stage, commit, AND PUSH them with a clear commit message describing what comments you addressed
6. You MUST push the changes to update the PR"

    local result
    local codex_exit_code=0
    result=$(run_codex_iteration "$comment_review_prompt" "$ADDITIONAL_FLAGS" "$error_log" "$iteration_display") || codex_exit_code=$?

    if [ $codex_exit_code -ne 0 ]; then
        echo "❌ $iteration_display Comment review attempt failed with exit code: $codex_exit_code" >&2
        return 1
    fi

    local parse_result=$(parse_codex_result "$result")
    if [ "$?" != "0" ]; then
        echo "❌ $iteration_display Comment review returned error: $parse_result" >&2
        return 1
    fi

    accumulate_iteration_tokens "$result"
    if [ "$LAST_ITER_TOKEN_TOTAL" != "0" ]; then
        printf "🔢 %s Comment review tokens: %s (running total: %s)\n" "$iteration_display" "$(format_tokens "$LAST_ITER_TOKEN_TOTAL")" "$(format_tokens $((total_input_tokens + total_output_tokens + total_reasoning_tokens)))" >&2
    fi

    echo "✅ $iteration_display Comment review iteration completed" >&2
    return 0
}

attempt_comment_fix_and_recheck() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local branch_name="$4"
    local iteration_display="$5"
    local main_branch="$6"
    local error_log="$7"

    local retry_attempt=1

    while [ $retry_attempt -le $COMMENT_REVIEW_MAX_ATTEMPTS ]; do
        if ! run_comment_fix_iteration "$iteration_display" "$pr_number" "$owner" "$repo" "$branch_name" "$error_log" "$retry_attempt"; then
            echo "⚠️  $iteration_display Comment review attempt $retry_attempt failed, proceeding to merge" >&2
            return 0
        fi

        sleep 5

        echo "🔍 $iteration_display Waiting for CI checks after comment fixes..." >&2
        if wait_for_pr_checks "$pr_number" "$owner" "$repo" "$iteration_display"; then
            echo "✅ $iteration_display CI still green after addressing comments!" >&2
            return 0
        fi

        echo "⚠️  $iteration_display CI failed after comment review attempt $retry_attempt" >&2
        retry_attempt=$((retry_attempt + 1))
    done

    echo "❌ $iteration_display CI broken after addressing comments" >&2
    return 1
}

# Validate the JSONL output of a codex exec iteration. We accept any output
# whose final relevant event is turn.completed; turn.failed or error events
# (or invalid JSON) are treated as failures.
parse_codex_result() {
    local result="$1"

    if [ -z "$result" ]; then
        echo "invalid_json"
        return 1
    fi

    # Must parse as JSONL.
    if ! echo "$result" | jq -s -e '.' >/dev/null 2>&1; then
        echo "invalid_json"
        return 1
    fi

    # Look for an error or turn.failed event anywhere in the stream.
    local has_error
    has_error=$(echo "$result" | jq -s -r '[.[] | select(.type == "turn.failed" or .type == "error")] | length' 2>/dev/null || echo "0")
    if [ "$has_error" != "0" ]; then
        echo "codex_error"
        return 1
    fi

    echo "success"
    return 0
}

# Extract the final agent_message text from the JSONL stream. This is what
# we scan for the COMPLETION_SIGNAL.
extract_codex_final_text() {
    local result="$1"
    echo "$result" | jq -s -r '[.[] | select(.type == "item.completed" and .item.type == "agent_message") | .item.text] | last // empty' 2>/dev/null
}

handle_iteration_error() {
    local iteration_display="$1"
    local error_type="$2"
    local error_output="$3"

    error_count=$((error_count + 1))
    extra_iterations=$((extra_iterations + 1))

    case "$error_type" in
        "exit_code")
            echo "" >&2
            echo "❌ $iteration_display Error occurred ($error_count consecutive errors):" >&2
            echo "" >&2
            if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
                echo "Error details:" >&2
                cat "$ERROR_LOG" >&2
            else
                echo "No error details captured in log file" >&2
                echo "Error log path: $ERROR_LOG" >&2
            fi
            echo "" >&2
            ;;
        "invalid_json")
            echo "" >&2
            echo "❌ $iteration_display Error: Invalid JSON response ($error_count consecutive errors):" >&2
            echo "" >&2
            echo "$error_output" >&2
            echo "" >&2
            ;;
        "codex_error")
            echo "" >&2
            echo "❌ $iteration_display Error in Codex CLI response ($error_count consecutive errors):" >&2
            echo "" >&2
            echo "$error_output" | jq -s -r '
                [.[] | select(.type == "turn.failed" or .type == "error")] |
                if length > 0 then (last | (.error.message // .message // "Unknown error")) else empty end
            ' >&2
            echo "" >&2
            ;;
    esac

    if [ $error_count -ge 3 ]; then
        echo "❌ Fatal: 3 consecutive errors occurred. Exiting." >&2
        exit 1
    fi

    return 1
}

handle_iteration_success() {
    local iteration_display="$1"
    local result="$2"
    local branch_name="$3"
    local main_branch="$4"

    local result_text
    result_text=$(extract_codex_final_text "$result")

    if [ -n "$result_text" ] && [[ "$result_text" == *"$COMPLETION_SIGNAL"* ]]; then
        completion_signal_count=$((completion_signal_count + 1))
        echo "" >&2
        echo "🎯 $iteration_display Completion signal detected ($completion_signal_count/$COMPLETION_THRESHOLD)" >&2
    else
        if [ $completion_signal_count -gt 0 ]; then
            echo "" >&2
            echo "🔄 $iteration_display Completion signal not found, resetting counter" >&2
        fi
        completion_signal_count=0
    fi

    accumulate_iteration_tokens "$result"
    if [ "$LAST_ITER_TOKEN_TOTAL" != "0" ]; then
        echo "" >&2
        printf "🔢 %s Iteration tokens: %s (in:%s out:%s reasoning:%s)\n" \
            "$iteration_display" \
            "$(format_tokens "$LAST_ITER_TOKEN_TOTAL")" \
            "$(format_tokens "$LAST_ITER_INPUT_TOKENS")" \
            "$(format_tokens "$LAST_ITER_OUTPUT_TOKENS")" \
            "$(format_tokens "$LAST_ITER_REASONING_TOKENS")" \
            >&2
        printf "   Running total: %s tokens\n" "$(format_tokens $((total_input_tokens + total_output_tokens + total_reasoning_tokens)))" >&2
    fi

    echo "✅ $iteration_display Work completed" >&2
    if [ "$ENABLE_COMMITS" = "true" ]; then
        if [ "$DISABLE_BRANCHES" = "true" ]; then
            if ! commit_on_current_branch "$iteration_display"; then
                error_count=$((error_count + 1))
                extra_iterations=$((extra_iterations + 1))
                echo "❌ $iteration_display Commit failed ($error_count consecutive errors)" >&2
                if [ $error_count -ge 3 ]; then
                    echo "❌ Fatal: 3 consecutive errors occurred. Exiting." >&2
                    exit 1
                fi
                return 1
            fi
        else
            if ! codext_commit "$iteration_display" "$branch_name" "$main_branch"; then
                error_count=$((error_count + 1))
                extra_iterations=$((extra_iterations + 1))
                echo "❌ $iteration_display PR merge queue failed ($error_count consecutive errors)" >&2
                if [ $error_count -ge 3 ]; then
                    echo "❌ Fatal: 3 consecutive errors occurred. Exiting." >&2
                    exit 1
                fi
                return 1
            fi
        fi
    else
        echo "⏭️  $iteration_display Skipping commits (--disable-commits flag set)" >&2
        if [ -n "$branch_name" ] && git rev-parse --git-dir > /dev/null 2>&1; then
            git checkout "$main_branch" >/dev/null 2>&1
            git branch -D "$branch_name" >/dev/null 2>&1 || true
        fi
    fi

    error_count=0
    if [ $extra_iterations -gt 0 ]; then
        extra_iterations=$((extra_iterations - 1))
    fi
    successful_iterations=$((successful_iterations + 1))
    return 0
}

execute_single_iteration() {
    local iteration_num=$1

    local iteration_display=$(get_iteration_display $iteration_num $MAX_RUNS $extra_iterations)
    echo "🔄 $iteration_display Starting iteration..." >&2

    local main_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    local branch_name=""

    if [ "$ENABLE_COMMITS" = "true" ] && [ "$DISABLE_BRANCHES" != "true" ]; then
        branch_name=$(create_iteration_branch "$iteration_display" "$iteration_num")
        if [ $? -ne 0 ] || [ -z "$branch_name" ]; then
            if git rev-parse --git-dir > /dev/null 2>&1; then
                echo "❌ $iteration_display Failed to create branch" >&2
                handle_iteration_error "$iteration_display" "exit_code" ""
                return 1
            fi
            branch_name=""
        fi
    fi

    local enhanced_prompt="${PROMPT_WORKFLOW_CONTEXT//COMPLETION_SIGNAL_PLACEHOLDER/$COMPLETION_SIGNAL}

$PROMPT

"

    if [ -f "$NOTES_FILE" ]; then
        local notes_content
        notes_content=$(cat "$NOTES_FILE")
        enhanced_prompt+="## CONTEXT FROM PREVIOUS ITERATION

The following is from $NOTES_FILE, maintained by previous iterations to provide context:

$notes_content

"
    fi

    enhanced_prompt+="## ITERATION NOTES

"

    if [ -f "$NOTES_FILE" ]; then
        enhanced_prompt+="$PROMPT_NOTES_UPDATE_EXISTING"
    else
        enhanced_prompt+="$PROMPT_NOTES_CREATE_NEW"
    fi

    enhanced_prompt+="$PROMPT_NOTES_GUIDELINES"

    echo "🤖 $iteration_display Running Codex CLI..." >&2

    local result
    local codex_exit_code=0
    result=$(run_codex_iteration "$enhanced_prompt" "$ADDITIONAL_FLAGS" "$ERROR_LOG" "$iteration_display") || codex_exit_code=$?

    if [ $codex_exit_code -ne 0 ]; then
        echo "" >&2
        echo "⚠️  Codex CLI command failed with exit code: $codex_exit_code" >&2
        if [ -n "$branch_name" ] && git rev-parse --git-dir > /dev/null 2>&1; then
            git checkout "$main_branch" >/dev/null 2>&1
            git branch -D "$branch_name" >/dev/null 2>&1 || true
        fi
        handle_iteration_error "$iteration_display" "exit_code" ""
        return 1
    fi

    local parse_result=$(parse_codex_result "$result")
    if [ "$?" != "0" ]; then
        if [ -n "$branch_name" ] && git rev-parse --git-dir > /dev/null 2>&1; then
            git checkout "$main_branch" >/dev/null 2>&1
            git branch -D "$branch_name" >/dev/null 2>&1 || true
        fi
        handle_iteration_error "$iteration_display" "$parse_result" "$result"
        return 1
    fi

    if [ -n "$REVIEW_PROMPT" ]; then
        if ! run_reviewer_iteration "$iteration_display" "$REVIEW_PROMPT" "$ERROR_LOG"; then
            echo "❌ $iteration_display Reviewer failed, aborting iteration" >&2
            if [ -n "$branch_name" ] && git rev-parse --git-dir > /dev/null 2>&1; then
                git checkout "$main_branch" >/dev/null 2>&1
                git branch -D "$branch_name" >/dev/null 2>&1 || true
            fi
            error_count=$((error_count + 1))
            extra_iterations=$((extra_iterations + 1))
            if [ $error_count -ge 3 ]; then
                echo "❌ Fatal: 3 consecutive errors occurred. Exiting." >&2
                exit 1
            fi
            return 1
        fi
    fi

    handle_iteration_success "$iteration_display" "$result" "$branch_name" "$main_branch"
    return 0
}

main_loop() {
    if [ -n "$MAX_DURATION" ]; then
        start_time=$(date +%s)
    fi

    while true; do
        local should_continue=false

        if [ -z "$MAX_RUNS" ] || [ "$MAX_RUNS" -eq 0 ] || [ $successful_iterations -lt $MAX_RUNS ]; then
            should_continue=true
        fi

        if [ -n "$MAX_TOKENS" ]; then
            local total_so_far=$((total_input_tokens + total_output_tokens + total_reasoning_tokens))
            if [ "$total_so_far" -ge "$MAX_TOKENS" ]; then
                should_continue=false
            fi
        fi

        if [ -n "$MAX_DURATION" ] && [ -n "$start_time" ]; then
            local current_time=$(date +%s)
            local elapsed_time=$((current_time - start_time))
            if [ $elapsed_time -ge $MAX_DURATION ]; then
                echo "" >&2
                echo "⏱️  Maximum duration reached ($(format_duration $elapsed_time))" >&2
                should_continue=false
            fi
        fi

        if [ -n "$MAX_RUNS" ] && [ "$MAX_RUNS" -ne 0 ] && [ $successful_iterations -ge $MAX_RUNS ]; then
            should_continue=false
        fi

        if [ $completion_signal_count -ge $COMPLETION_THRESHOLD ]; then
            echo "" >&2
            echo "🎉 Project completion signal detected $completion_signal_count times consecutively!" >&2
            should_continue=false
        fi

        if [ "$should_continue" = "false" ]; then
            break
        fi

        execute_single_iteration $i

        sleep 1
        i=$((i + 1))
    done
}

show_completion_summary() {
    local elapsed_msg=""
    if [ -n "$start_time" ]; then
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        elapsed_msg=" (elapsed: $(format_duration $elapsed_time))"
    fi

    local total_tokens=$((total_input_tokens + total_output_tokens + total_reasoning_tokens))
    local token_msg=""
    if [ "$total_tokens" -gt 0 ]; then
        token_msg=$(printf "Total tokens: %s (in:%s out:%s reasoning:%s)" \
            "$(format_tokens "$total_tokens")" \
            "$(format_tokens "$total_input_tokens")" \
            "$(format_tokens "$total_output_tokens")" \
            "$(format_tokens "$total_reasoning_tokens")")
    fi

    if [ $completion_signal_count -ge $COMPLETION_THRESHOLD ]; then
        if [ -n "$token_msg" ]; then
            printf "✨ Project completed! Detected completion signal %d times in a row. %s%s\n" "$completion_signal_count" "$token_msg" "$elapsed_msg"
        else
            printf "✨ Project completed! Detected completion signal %d times in a row.%s\n" "$completion_signal_count" "$elapsed_msg"
        fi
    elif [ -n "$MAX_RUNS" ] && [ $MAX_RUNS -ne 0 ] || [ -n "$MAX_TOKENS" ] || [ -n "$MAX_DURATION" ]; then
        if [ -n "$token_msg" ]; then
            printf "🎉 Done. %s%s\n" "$token_msg" "$elapsed_msg"
        else
            printf "🎉 Done%s\n" "$elapsed_msg"
        fi
    fi
}

main() {
    if [ "$1" = "update" ]; then
        shift
        parse_update_flags "$@"
        handle_update_command
        exit 0
    fi

    parse_arguments "$@"
    validate_arguments
    validate_requirements

    check_for_updates false "$@"

    if [ "$LIST_WORKTREES" = "true" ]; then
        list_worktrees
    fi

    setup_worktree

    ERROR_LOG=$(mktemp)
    trap "rm -f $ERROR_LOG; cleanup_worktree" EXIT

    main_loop
    show_completion_summary

    cleanup_worktree
}

if [ -z "$TESTING" ]; then
    main "$@"
fi
