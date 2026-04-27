# Codex CLI options reference (as exposed through codext)

This document is the complete inventory of `codex exec` options users can pass through `codext`, plus the `config.toml` keys most useful for tuning iterative loops. **Only GA, publicly documented options are listed** — experimental subcommands and undocumented source-only flags are intentionally excluded.

> **Sources of truth:** [Codex CLI reference](https://developers.openai.com/codex/cli/reference/), [Non-interactive mode](https://developers.openai.com/codex/noninteractive), [Configuration reference](https://developers.openai.com/codex/config-reference), [Codex models](https://developers.openai.com/codex/models), [Speed](https://developers.openai.com/codex/speed). Re-check if you're chasing a bug — these change frequently.

---

## How codext forwards flags to codex

Codext uses `codex exec` as its single backend. Three layers of forwarding:

1. **Defaults** — codext always passes `--json --skip-git-repo-check --full-auto` to every `codex exec` invocation. (`--yolo`/`--dangerously-bypass-approvals-and-sandbox` overrides `--full-auto` if the user passes it.)
2. **Convenience shortcuts** — codext owns a small set of ergonomic flags that translate to `-c key=value` overrides (e.g. `--effort high` → `-c model_reasoning_effort=high`). These are listed below under *Convenience shortcuts*.
3. **Pass-through** — every flag codext doesn't recognize is appended verbatim to the `codex exec` invocation. So `codext -p "..." -m 5 --model gpt-5.5 --sandbox workspace-write` works as you'd expect.

---

## Convenience shortcuts (codext-native)

These exist solely to surface frequently-tuned codex settings as proper flags rather than forcing users to remember the corresponding `-c key=value` syntax.

| Codext flag | Maps to | Allowed values | Default |
|---|---|---|---|
| `--effort <level>` | `-c model_reasoning_effort=<level>` | `minimal`, `low`, `medium`, `high`, `xhigh` | model preset |
| `--fast` | `-c service_tier=fast` | (boolean flag) | Standard tier |

> `xhigh` is model-dependent — not every model accepts it. `--fast` is GA; only `GPT-5.5` and `GPT-5.4` actually run faster on the fast service tier (2.5× and 2× credit consumption respectively, see [Speed](https://developers.openai.com/codex/speed)).

---

## Pass-through `codex exec` flags (GA)

Everything below is a GA `codex exec` flag. Pass it directly to `codext` and it lands on the underlying `codex exec` invocation.

### Model & provider

| Flag | Type | Description |
|---|---|---|
| `--model <name>` / `-m` | string | Override the default model. `gpt-5.5` (ChatGPT auth only), `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.3-codex`, etc. **Note:** codext's `-m` already means `--max-runs`, so always use the long form `--model`. |
| `--oss` | bool | Use the local OSS provider (defaults to Ollama). Equivalent to `-c model_provider="oss"`. |
| `--profile <name>` | string | Pick a `[profiles.<name>]` block from `~/.codex/config.toml`. **Note:** codext's `-p` already means `--prompt`, so always use the long form `--profile`. |

### Sandbox & approvals

| Flag | Type | Description |
|---|---|---|
| `--sandbox <mode>` / `-s` | enum | `read-only` \| `workspace-write` \| `danger-full-access`. |
| `--ask-for-approval <mode>` / `-a` | enum | `untrusted` \| `on-request` \| `never`. (`on-failure` is deprecated.) |
| `--full-auto` | bool | Preset combo: `--sandbox workspace-write` + `--ask-for-approval on-request`. **Codext sets this by default.** |
| `--dangerously-bypass-approvals-and-sandbox` (alias `--yolo`) | bool | Bypass everything. Overrides `--full-auto`. **Use only inside an isolated runner.** |
| `--add-dir <path>` | path (repeatable) | Grant write access to additional directories outside the workspace. |

### Working directory & files

| Flag | Type | Description |
|---|---|---|
| `--cd <path>` / `-C` | path | Set the workspace root before running. |
| `--image <path>` / `-i` | path[,path...] | Attach images to the initial prompt. Repeatable or comma-separated. |
| `--ephemeral` | bool | Don't persist session rollout files to disk. |
| `--skip-git-repo-check` | bool | Allow running outside a Git repo. **Codext sets this by default.** |

### Output & events

| Flag | Type | Description |
|---|---|---|
| `--json` (alias `--experimental-json`) | bool | Emit newline-delimited JSON events. **Codext sets this by default** — codext's iteration loop parses the JSONL stream for token counts. |
| `--output-last-message <file>` / `-o` | path | Write the assistant's final message to a file. |
| `--output-schema <file>` | path (JSON Schema) | Constrain the final response to a JSON Schema. |
| `--color <mode>` | enum | `always` \| `never` \| `auto`. |

### Web search

| Flag | Type | Description |
|---|---|---|
| `--search` | bool | Switch from cached to live web search for this run (sets `web_search = "live"`). |

### Config overrides

| Flag | Type | Description |
|---|---|---|
| `-c <key>=<value>` / `--config` | repeatable | Inline override for any `config.toml` key. Values parse as JSON when possible; otherwise treated as a literal string. |

### `codex exec resume` (subcommand)

Codext doesn't currently use `codex exec resume`, but if you build a custom workflow on top of codext's iteration loop, the flags are: `[SESSION_ID]`, `--last`, `--all`, `-i/--image`, `[PROMPT]`. See the [official reference](https://developers.openai.com/codex/cli/reference#codex-exec).

---

## Useful `config.toml` keys (via `-c key=value`)

For settings that don't have a dedicated CLI flag, `-c key=value` is the way to override them per-run. The keys below are the ones most useful for iterative codext runs.

### Model behavior

| Key | Type | Notes |
|---|---|---|
| `model` | string | Same as `--model`. |
| `model_reasoning_effort` | `minimal`\|`low`\|`medium`\|`high`\|`xhigh` | Codext's `--effort` shortcut sets this. Responses API only; `xhigh` is model-dependent. |
| `model_reasoning_summary` | `auto`\|`concise`\|`detailed`\|`none` | How much reasoning summary the model emits. |
| `model_verbosity` | `low`\|`medium`\|`high` | GPT-5 Responses API verbosity. Pre-GPT-5 models ignore. |
| `model_supports_reasoning_summaries` | bool | Force-enable/disable reasoning metadata. |
| `oss_provider` | `lmstudio`\|`ollama` | Which local provider `--oss` uses. |
| `service_tier` | `flex`\|`fast` | Codext's `--fast` shortcut sets this to `fast`. |

### Sandbox & approvals (config keys)

| Key | Type | Notes |
|---|---|---|
| `approval_policy` | `untrusted`\|`on-request`\|`never`\|granular table | Same as `--ask-for-approval`, plus a `granular` form for fine-grained control. |
| `sandbox_mode` | `read-only`\|`workspace-write`\|`danger-full-access` | Same as `--sandbox`. |
| `sandbox_workspace_write.network_access` | bool | Allow outbound network in workspace-write mode. |
| `sandbox_workspace_write.writable_roots` | array | Extra writable roots in workspace-write mode. |
| `sandbox_workspace_write.exclude_tmpdir_env_var` | bool | Exclude `$TMPDIR` from writable roots. |
| `sandbox_workspace_write.exclude_slash_tmp` | bool | Exclude `/tmp` from writable roots. |

### Web search (config keys)

| Key | Type | Notes |
|---|---|---|
| `web_search` | `disabled`\|`cached`\|`live` | Default `cached`. `--search` flag flips this to `live`. |
| `tools.web_search` | bool or table | Same effect as legacy boolean. Table form supports `context_size`, `allowed_domains`, `location`. |

### Quieter logs (useful for codext loops)

| Key | Type | Notes |
|---|---|---|
| `hide_agent_reasoning` | bool | Suppress reasoning events in `codex exec` output. |
| `show_raw_agent_reasoning` | bool | Surface raw reasoning content when models emit it. |

### Notify hook

| Key | Type | Notes |
|---|---|---|
| `notify` | array | Command invoked when a turn finishes; receives a JSON payload. Useful for webhook integrations from inside the loop. |

---

## Putting it together — recipes

```bash
# Cheap, fast, good-enough iteration loop
codext -p "Add unit tests under src/" -m 5 \
       --model gpt-5.4-mini \
       --effort low \
       --max-tokens 2000000

# High-effort, multi-step refactor
codext -p "Migrate the auth module from session cookies to JWT" -m 10 \
       --model gpt-5.5 \
       --effort high \
       --max-tokens 4000000 \
       -r "Run npm test and npm run lint, fix any failures"

# Constrained sandbox + extra writable directory
codext -p "Update the SDK examples in /examples and /docs" -m 5 \
       --model gpt-5.4 \
       --sandbox workspace-write \
       --add-dir ../shared-fixtures

# Output schema for downstream tooling
codext -p "Extract project metadata" -m 1 \
       --model gpt-5.4-mini \
       --output-schema ./schema.json \
       -o ./project-metadata.json

# Live web search (e.g. when fixing a "what's the latest of X library" bug)
codext -p "Upgrade Express to the latest stable, fix any breaking changes" -m 3 \
       --model gpt-5.5 \
       --search

# Custom config profile
codext -p "Run nightly tests" -m 1 \
       --profile ci \
       --effort medium

# Direct -c override for something without a dedicated flag
codext -p "Generate verbose docs" -m 2 \
       --model gpt-5.5 \
       -c model_verbosity=high \
       -c model_reasoning_summary=detailed
```

---

## What codext deliberately does NOT expose

The following `codex` subcommands and flags exist but **don't apply to codext's iterative-loop use case**. Use the upstream `codex` CLI directly if you need them:

| Codex feature | Why codext doesn't expose it |
|---|---|
| `codex` (interactive TUI) | Codext is a non-interactive automation wrapper; uses `codex exec` only. |
| `codex resume` / `codex fork` | Codext's iteration loop uses `--full-auto` fresh sessions per iteration with `SHARED_TASK_NOTES.md` for hand-off context. |
| `codex login` / `codex logout` | Run these once outside codext; codext respects existing auth. |
| `codex cloud`, `codex apply`, `codex app`, `codex app-server` | Cloud, desktop, or app-server flows — orthogonal to the iterative-PR pattern. Marked **experimental** by upstream. |
| `codex mcp` | Configure MCP servers in `~/.codex/config.toml` once; they're inherited by every codex invocation including codext's. Marked **experimental** by upstream. |
| `codex execpolicy`, `codex sandbox` | Standalone debugging tools. Marked **experimental** by upstream. |
| `--remote ws://...` + WebSocket auth flags | Remote app-server connections, not for non-interactive runs. |
| `--no-alt-screen`, `tui.*` keys | TUI-only, irrelevant to `codex exec`. |
| `--ignore-user-config`, `--ignore-rules` | Present in source but not in the public CLI reference — treat as internal. |
