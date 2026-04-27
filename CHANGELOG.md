# Changelog

## v0.1.2

Codex tuning shortcuts and documentation overhaul.

- New `--effort minimal|low|medium|high|xhigh` flag — maps to `-c model_reasoning_effort=<level>` so you can crank reasoning effort without remembering the `-c` syntax.
- New `--fast` flag — maps to `-c service_tier=fast`, the Codex Fast service tier. 1.5× faster output for `gpt-5.5`/`gpt-5.4` at higher credit/token cost.
- `--help` now lists the most useful `codex exec` pass-through flags (`--model`, `--sandbox`, `--ask-for-approval`, `--add-dir`, `--cd`, `--search`, `--image`, `--oss`, `--output-schema`, `--output-last-message`, `--ephemeral`, `--color`, `-c key=value`).
- New [`docs/codex-options.md`](docs/codex-options.md) — comprehensive, GA-only reference of every Codex CLI flag and `config.toml` key codext exposes, sourced directly from `developers.openai.com/codex/cli/reference`.
- New [`pricing.md`](pricing.md) — per-model API/credit pricing with `--max-tokens` to-dollar conversion tables across 60/40, 50/50, and 30/70 input/output mixes.
- Logo: featured in the README header (gradient app-icon themed off the OpenAI Codex desktop icon, with a loop wrapping the `>_` cursor).

## v0.1.1

Bugfix release.

- Running token total now actually accumulates across iterations. The previous release computed per-iteration tokens correctly but the running total stayed at 0 because `accumulate_iteration_tokens` was being called inside `$(…)`, which forks a subshell and discards global-variable updates.
- Cleaner streaming display when codex emits an error: no longer prints the same `❌` line twice when codex pairs an `error` event with a `turn.failed` event.
- Installer's "Get started" hint now shows the short, auto-detecting form (`codext -p "your task" -m 5`) instead of an obsolete `--owner ... --repo ...` example.

## v0.1.0

Initial release.

### Features

- Iterative `codex exec` loop with branch-per-iteration PR creation
- Full PR lifecycle via `gh`: create → wait for checks → wait for review → merge or close
- CI failure auto-retry (`--ci-retry-max`) and PR comment review (`--comment-review-max`)
- Optional reviewer pass after each iteration (`-r`)
- `SHARED_TASK_NOTES.md` for cross-iteration context handoff
- Git worktree support for parallel runs (`--worktree`)
- Self-update via GitHub releases (`codext update`)
- Completion-signal early stop (`CODEXT_PROJECT_COMPLETE`), dry-run mode, gitmoji-rendered release notes
- GitHub owner/repo auto-detection from `git remote`
- Throttles: `--max-runs`, `--max-tokens`, `--max-duration`
- Any unknown CLI flag is forwarded verbatim to `codex exec` (so `--model`, `--sandbox`, `--add-dir`, `--yolo`, `-c key=value` all work without script changes)
