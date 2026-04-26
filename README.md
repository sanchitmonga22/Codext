# Codext

> *Codex, with a silent T — borrowed from [Loopt](https://en.wikipedia.org/wiki/Loopt). The loop is the point.*

Run OpenAI's [Codex CLI](https://github.com/openai/codex) in a loop — autonomously opening pull requests, waiting for CI and reviews, and merging them — so multi-step refactors, test sweeps, and dependency upgrades complete while you sleep.

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

# Full auto-on-everything (overrides default --full-auto)
codext -p "Wipe and rebuild docs" -m 1 --yolo

# Run with a reviewer pass after each iteration
codext -p "Add new feature" -m 5 \
  -r "Run npm test and npm run lint, fix any failures"

# Multiple instances in parallel (separate worktrees)
codext -p "Task A" -m 5 --worktree task-a
codext -p "Task B" -m 5 --worktree task-b
```

Run `codext --help` for the full flag list.

## Requirements

- [Codex CLI](https://github.com/openai/codex) — log in once with `codex login`
- [GitHub CLI (`gh`)](https://cli.github.com) — `gh auth login`
- `jq` — JSON parsing
- A GitHub repo with `origin` set (unless you pass `--disable-commits`)

## Forwarding flags to `codex exec`

Any flag the script doesn't recognize is forwarded to `codex exec`. Common ones:

- `--model gpt-5.5` (or `gpt-5.4`)
- `--sandbox read-only|workspace-write|danger-full-access`
- `--add-dir <path>` (grant Codex write access to extra directories)
- `--yolo` / `--dangerously-bypass-approvals-and-sandbox` (overrides default `--full-auto`)
- `-c key=value` (any inline config override)

## Throttles

Pick one (or combine — first one to trip wins):

- `-m, --max-runs <number>` — cap by successful iterations
- `--max-tokens <number>` — cap by total tokens (input + output + reasoning) across all iterations
- `--max-duration <duration>` — cap by wall-clock time (`30m`, `2h`, `1h30m`, etc.)

## Limitations

- **No dollar cost tracking.** Codex CLI's JSONL stream emits token counts on every `turn.completed` event but no dollar amount. ChatGPT plans include Codex flat-rate; only API-key users have meaningful dollar costs, and pricing varies by model. Use `--max-tokens` instead.
- **No fine-grained tool allowlisting** — Codex uses sandbox modes (`read-only` / `workspace-write` / `danger-full-access`), not per-tool allowlists.

## Credits

The iterative-PR-loop pattern is borrowed from [continuous-claude](https://github.com/AnandChowdhary/continuous-claude) by [Anand Chowdhary](https://github.com/AnandChowdhary). Thanks for the original idea — go give the upstream project a star.

## License

MIT — see [LICENSE](LICENSE).
