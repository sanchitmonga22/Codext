<p align="center">
  <img src="assets/logo/codext-logo.svg" alt="Codext logo" width="180" height="180">
</p>

<h1 align="center">Codext</h1>

<p align="center"><em>Codex, with a silent T — borrowed from <a href="https://en.wikipedia.org/wiki/Loopt">Loopt</a>. The loop is the point.</em></p>

Run OpenAI's [Codex CLI](https://github.com/openai/codex) in a loop — autonomously opening pull requests, waiting for CI and reviews, and merging them — so multi-step refactors, test sweeps, and dependency upgrades complete while you sleep.

> *Codext was itself built using Codex CLI. The loop ate its own tail.*

## How it works

Codext drives `codex exec` iteratively against your repo. Each iteration:

1. Creates a new branch and runs `codex exec` against your prompt
2. Asks Codex to write a commit message and commit the changes
3. Pushes the branch and opens a PR with `gh`
4. Waits for required CI checks and code reviews
5. Merges on success, or auto-attempts a CI fix and PR-comment fix before closing
6. Pulls main and repeats

A `SHARED_TASK_NOTES.md` file is maintained by Codex itself to pass context between iterations — clean handoff notes between runs, like a relay race baton.

## Quick start

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/sanchitmonga22/Codext/main/install.sh | bash
```

Or, manually:

```bash
curl -fsSL https://raw.githubusercontent.com/sanchitmonga22/Codext/main/codext.sh -o ~/.local/bin/codext
chmod +x ~/.local/bin/codext
```

### Use

```bash
# Run 5 iterations
codext -p "Add unit tests to all files under src/" -m 5

# Cap by tokens (sum of input + output + reasoning across all iterations)
codext -p "Add tests" --max-tokens 2000000

# Time-box for 90 minutes
codext -p "Refactor module" --max-duration 1h30m

# Run on the current branch without creating PRs
codext -p "Quick fixes" -m 3 --disable-branches

# Pick a model (forwarded to codex exec)
codext -p "Add tests" -m 5 --model gpt-5.5

# Crank up reasoning effort for a hard refactor
codext -p "Refactor the auth module" -m 5 --model gpt-5.5 --effort high

# Fast service tier (1.5x faster on gpt-5.5 / gpt-5.4)
codext -p "Ship the launch page" -m 3 --model gpt-5.5 --fast --effort high

# Full auto-on-everything (overrides default --full-auto)
codext -p "Wipe and rebuild docs" -m 1 --yolo

# Run with a reviewer pass after each iteration
codext -p "Add new feature" -m 5 \
  -r "Run npm test and npm run lint, fix any failures"

# Multiple instances in parallel (separate worktrees)
codext -p "Task A" -m 5 --worktree task-a
codext -p "Task B" -m 5 --worktree task-b
```

Run `codext --help` for the inline reference, or read on for the full table.

## Requirements

- [Codex CLI](https://github.com/openai/codex) — log in once with `codex login`
- [GitHub CLI (`gh`)](https://cli.github.com) — `gh auth login`
- `jq` — JSON parsing
- A GitHub repo with `origin` set (unless you pass `--disable-commits`)

## Commands

| Command | Description |
|---|---|
| `codext` *(default)* | Run the iterative loop. Accepts every flag in the *Options* tables below. |
| `codext update` | Check for and install the latest release from GitHub. Accepts `--auto-update` (skip the confirmation prompt) and `--disable-updates`. |

## Options

### Required: prompt + at least one budget

| Flag | Type | Description |
|---|---|---|
| `-p, --prompt <text>` | string | Prompt/goal Codex works on each iteration. |
| `-m, --max-runs <number>` | int ≥ 0 | Cap by successful iterations. `0` means unlimited (only valid combined with `--max-tokens` or `--max-duration`). |
| `--max-tokens <number>` | int > 0 | Cap by total tokens (input + output + reasoning) summed across all iterations. |
| `--max-duration <duration>` | `30m`, `2h`, `1h30m`, `90s`, … | Cap by wall-clock time. |

> A prompt is always required. **At least one** of `-m` / `--max-tokens` / `--max-duration` is required; combine them and the first cap to trip wins.

### PR workflow

| Flag | Default | Description |
|---|---|---|
| `--owner <owner>` | auto-detected from `git remote` | GitHub org/user. |
| `--repo <repo>` | auto-detected from `git remote` | Repo name. |
| `--git-branch-prefix <prefix>` | `codext/` | Branch name prefix used for each iteration's branch. |
| `--merge-strategy <strategy>` | `squash` | PR merge strategy: `squash`, `merge`, or `rebase`. |
| `--notes-file <file>` | `SHARED_TASK_NOTES.md` | Path to the cross-iteration handoff notes file Codex maintains. |
| `--disable-commits` | off (commits enabled) | Skip all commits and PRs — just run `codex exec` and stop. |
| `--disable-branches` | off (branches enabled) | Commit on the current branch instead of opening a per-iteration branch + PR. |

### Worktrees (parallel runs)

| Flag | Default | Description |
|---|---|---|
| `--worktree <name>` | none | Run inside a git worktree with this name (creates if missing). Useful for running multiple codext instances side-by-side. |
| `--worktree-base-dir <path>` | `../codext-worktrees` | Where worktrees live. |
| `--cleanup-worktree` | off | Remove the worktree after the run finishes. |
| `--list-worktrees` | — | Print all active git worktrees and exit. |

### Reviewer / CI / PR comments

| Flag | Default | Description |
|---|---|---|
| `-r, --review-prompt <text>` | none | Run a reviewer pass after each iteration to validate/fix changes (e.g. run tests + lint). |
| `--disable-ci-retry` | off (retry enabled) | Don't auto-attempt to fix CI failures. |
| `--ci-retry-max <n>` | `1` | Maximum CI fix attempts per PR. |
| `--disable-comment-review` | off (review enabled) | Don't auto-address review comments on the PR. |
| `--comment-review-max <n>` | `1` | Maximum comment-review attempts per PR. |

### Early stop on project completion

| Flag | Default | Description |
|---|---|---|
| `--completion-signal <phrase>` | `CODEXT_PROJECT_COMPLETE` | Exact phrase Codex outputs when it believes the *entire* goal is finished. |
| `--completion-threshold <n>` | `3` | Number of consecutive iterations that must emit the signal before codext exits early. |

### Codex model tuning (shortcuts)

| Flag | Maps to | Description |
|---|---|---|
| `--effort <level>` | `-c model_reasoning_effort=<level>` | Reasoning effort: `minimal` \| `low` \| `medium` \| `high` \| `xhigh`. (`xhigh` is model-dependent.) |
| `--fast` | `-c service_tier=fast` | Codex Fast service tier — 1.5× faster output for `gpt-5.5` and `gpt-5.4` at higher credit/token cost. |

### Updates

| Flag | Default | Description |
|---|---|---|
| `--auto-update` | prompts before applying | Install available updates non-interactively at startup. |
| `--disable-updates` | off (checks enabled) | Skip update checks entirely. Combine with `--auto-update` for fully unattended runs. |

### Misc

| Flag | Description |
|---|---|
| `--dry-run` | Simulate execution without making any changes (no `codex exec`, no commits, no PRs). |
| `-h, --help` | Show the inline help text. |
| `-v, --version` | Print the codext version. |

## Codex passthrough flags

Any flag codext doesn't recognize is forwarded to `codex exec` verbatim. Codext also adds `--json --skip-git-repo-check --full-auto` to every run by default — pass `--yolo` to override `--full-auto`.

The most useful pass-through flags:

| Flag | Description |
|---|---|
| `--model <name>` | `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.3-codex`, … (see [pricing.md](pricing.md) for per-model cost). |
| `--oss` | Use the local OSS provider (requires running Ollama). |
| `--profile <name>` | Pick a `[profiles.<name>]` block from `~/.codex/config.toml`. |
| `--sandbox <mode>` | `read-only` \| `workspace-write` \| `danger-full-access`. |
| `--ask-for-approval <mode>` | `untrusted` \| `on-request` \| `never`. |
| `--yolo` *(alias for `--dangerously-bypass-approvals-and-sandbox`)* | Bypass approvals and sandboxing. Use only inside an isolated runner. |
| `--add-dir <path>` | Grant Codex write access to extra directories outside the workspace. |
| `--cd <path>` | Set the working directory before running. |
| `--search` | Switch from cached to live web search for the run. |
| `--image <path>` | Attach images to the initial prompt (repeatable, comma-separated). |
| `--ephemeral` | Don't persist session rollout files to disk. |
| `--output-last-message <file>` *(alias `-o`)* | Write the final agent message to a file. |
| `--output-schema <file>` | Constrain the final response to a JSON Schema. |
| `--color <mode>` | `always` \| `never` \| `auto`. |
| `-c key=value` | Inline override for any `config.toml` key (e.g. `-c model_verbosity=high`). |

> **Flag collisions to know:** codext's `-m` is `--max-runs` (codex uses `-m` for `--model`); codext's `-p` is `--prompt` (codex uses `-p` for `--profile`); codext's `-r` is `--review-prompt`. **Always use the long-form `--model`, `--profile`** when targeting codex.

See [`docs/codex-options.md`](docs/codex-options.md) for the **full** GA-only flag matrix and the most useful `config.toml` keys, and [`pricing.md`](pricing.md) for token-budget-to-dollar mapping per model.

## Limitations

- **No dollar cost tracking.** Codex CLI's JSONL stream emits token counts on every `turn.completed` event but no dollar amount. ChatGPT plans include Codex flat-rate; only API-key users have meaningful dollar costs, and pricing varies by model. Use `--max-tokens` instead — see [pricing.md](pricing.md) for token→$ conversion tables.
- **No fine-grained tool allowlisting.** Codex uses sandbox modes (`read-only` / `workspace-write` / `danger-full-access`), not per-tool allowlists.

## Credits

The iterative-PR-loop pattern is borrowed from [continuous-claude](https://github.com/AnandChowdhary/continuous-claude) by [Anand Chowdhary](https://github.com/AnandChowdhary). Thanks for the original idea — go give the upstream project a star.

## License

MIT — see [LICENSE](LICENSE).
