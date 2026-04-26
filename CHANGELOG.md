# Changelog

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
