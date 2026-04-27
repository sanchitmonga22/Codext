# Codex CLI Pricing Reference

A consolidated pricing & usage-limit reference for every model the OpenAI Codex CLI can drive — useful for sizing `codext --max-tokens` budgets and choosing the right model for an iterative loop.

> **Last updated:** 2026‑04‑27.
> Sources: [Codex pricing page](https://developers.openai.com/codex/pricing/), [Codex models](https://developers.openai.com/codex/models), [Codex CLI reference](https://developers.openai.com/codex/cli/reference/), [Speed](https://developers.openai.com/codex/speed), [Codex rate card](https://help.openai.com/en/articles/20001106-codex-rate-card), [OpenAI API pricing](https://platform.openai.com/docs/pricing). Prices and limits change frequently — re-verify against the canonical pages before committing real money.

---

## TL;DR — what should I pass to `codext --model`?

| Goal | Model | Why |
|---|---|---|
| Best results, complex multi-step refactors | `gpt-5.5` | Frontier model. ChatGPT-auth only — not on API key. |
| Fall back when 5.5 isn't in your account yet | `gpt-5.4` | Previous flagship; available on every auth path. |
| Routine code, faster + cheaper local turns | `gpt-5.4-mini` | ~3× cheaper than `gpt-5.4`, ~5× cheaper than `gpt-5.5`. |
| Cloud tasks / GitHub code review | `gpt-5.3-codex` | The model OpenAI uses behind cloud Codex tasks. Available with API key. |
| Near-instant feedback loop (Pro only, preview) | `gpt-5.3-codex-spark` | Research preview, Pro subscribers only. Specialized low-latency hardware. |
| Legacy / cost-optimized | `gpt-5.2`, `gpt-5.2-codex` | Older Codex-tuned model still available. |
| Local OSS via Ollama | pass `--oss` to `codex` | Equivalent to `-c model_provider="oss"`. |
| Anything else | any model that supports Chat Completions or Responses APIs | Configurable in `~/.codex/config.toml`. |

`codext` forwards `--model <name>` straight through to `codex exec`, so any of the above values work with `codext -p "..." -m 5 --model gpt-5.4-mini`.

---

## Models supported in Codex CLI

### Recommended (first-party, ChatGPT-auth)

| Model | Best for | Notes |
|---|---|---|
| `gpt-5.5` | Complex coding, multi-step planning, research workflows | OpenAI's current frontier. ChatGPT auth only. Significantly fewer tokens than `gpt-5.4` for similar quality. |
| `gpt-5.4` | Drop-in replacement when `gpt-5.5` not yet rolled out | Available on all auth paths (ChatGPT + API). |
| `gpt-5.4-mini` | Fast, cheap routine local tasks; subagents | ~5× lower input cost vs `gpt-5.4`. Higher rate limits. |
| `gpt-5.3-codex` | Cloud Codex tasks, GitHub code review | The model OpenAI runs cloud tasks on. |
| `gpt-5.3-codex-spark` | Real-time, near-instant edits | **Research preview, ChatGPT Pro only.** Separate usage limit. |

### Image generation

| Model | Notes |
|---|---|
| `gpt-image-2` | Built-in image generation. Counts toward Codex usage limits 3–5× faster than text-only turns. With `OPENAI_API_KEY` set, billed at API rates instead. |

### Legacy models (still configurable)

`gpt-5.2`, `gpt-5.2-codex`, `gpt-5.1`, `gpt-5.1-codex-max`, `gpt-5`, `gpt-5-codex`, `gpt-5-codex-mini` — covered by the legacy rate card averages.

### Other (BYO)

The Codex CLI accepts any model exposed by a provider that supports either the [Chat Completions](https://platform.openai.com/docs/api-reference/chat) or [Responses](https://platform.openai.com/docs/api-reference/responses) APIs. Configure in `~/.codex/config.toml` or pass `--model <name>`. (Chat Completions support is deprecated and will eventually be removed.)

---

## API key pricing (per 1M tokens, USD)

This is what matters for `codext` budgeting when you authenticate with `OPENAI_API_KEY` — every token costs real dollars.

### Standard tier

| Model | Input | Cached input | Output |
|---|---:|---:|---:|
| gpt-5.5 *(<272K context)* | $5.00 | $0.50 | $30.00 |
| gpt-5.5-pro *(<272K context)* | $30.00 | — | $180.00 |
| gpt-5.4 *(<272K context)* | $2.50 | $0.25 | $15.00 |
| gpt-5.4-mini | $0.75 | $0.075 | $4.50 |
| gpt-5.4-nano | $0.20 | $0.02 | $1.25 |
| gpt-5.4-pro *(<272K context)* | $30.00 | — | $180.00 |
| gpt-5.2 | $1.75 | $0.175 | $14.00 |
| gpt-5.2-codex | $1.75 | $0.175 | $14.00 |
| gpt-5.2-pro | $21.00 | — | $168.00 |
| gpt-5.1 | $1.25 | $0.125 | $10.00 |
| gpt-5 | $1.25 | $0.125 | $10.00 |
| gpt-5-mini | $0.25 | $0.025 | $2.00 |
| gpt-5-nano | $0.05 | $0.005 | $0.40 |
| gpt-5-pro | $15.00 | — | $120.00 |
| gpt-4.1 | $2.00 | $0.50 | $8.00 |
| gpt-4.1-mini | $0.40 | $0.10 | $1.60 |
| gpt-4.1-nano | $0.10 | $0.025 | $0.40 |

### Batch tier (asynchronous; ~50% off Standard)

| Model | Input | Cached input | Output |
|---|---:|---:|---:|
| gpt-5.5 | $2.50 | $0.25 | $15.00 |
| gpt-5.4 | $1.25 | $0.13 | $7.50 |
| gpt-5.4-mini | $0.375 | $0.0375 | $2.25 |
| gpt-5.4-nano | $0.10 | $0.01 | $0.625 |
| gpt-5.2 | $0.875 | $0.0875 | $7.00 |
| gpt-5.2-pro | $10.50 | — | $84.00 |

### Flex tier (background/non-time-sensitive)

| Model | Input | Cached input | Output |
|---|---:|---:|---:|
| gpt-5.5 | $2.50 | $0.25 | $15.00 |
| gpt-5.4 | $1.25 | $0.13 | $7.50 |
| gpt-5.4-mini | $0.375 | $0.0375 | $2.25 |
| gpt-5.2 | $0.875 | $0.0875 | $7.00 |

### Priority tier (low-latency, premium)

| Model | Input | Cached input | Output |
|---|---:|---:|---:|
| gpt-5.5 | $12.50 | $1.25 | $75.00 |
| gpt-5.4 | $5.00 | $0.50 | $30.00 |
| gpt-5.4-mini | $1.50 | $0.15 | $9.00 |
| gpt-5.2 | $3.50 | $0.35 | $28.00 |

> Codex CLI uses **Standard** pricing by default when authenticated with an API key.

---

## ChatGPT plan usage limits (Codex CLI, per 5-hour window)

For users authenticated via ChatGPT, you don't pay per token — you have **rate limits** instead. Numbers are ranges (small ↔ large messages).

### Plus ($20/mo) — Codex CLI

| Model | Local messages | Cloud tasks | Code reviews |
|---|---:|---:|---:|
| GPT-5.5 | 15–80 | — | — |
| GPT-5.4 | 20–100 | — | — |
| GPT-5.4-mini | 60–350 | — | — |
| GPT-5.3-Codex | 30–150 | 10–60 | 20–50 |

### Pro 5x ($100/mo) — Codex CLI

> 2× promo through May 31, 2026 → effectively 10× Plus.

| Model | Local messages | Cloud tasks | Code reviews |
|---|---:|---:|---:|
| GPT-5.5 | 80–400 | — | — |
| GPT-5.4 | 100–500 | — | — |
| GPT-5.4-mini | 300–1750 | — | — |
| GPT-5.3-Codex | 150–750 | 50–300 | 100–250 |

### Pro 20x ($200/mo) — Codex CLI

> 25× Plus on 5-hour limits through May 31, 2026.

| Model | Local messages | Cloud tasks | Code reviews |
|---|---:|---:|---:|
| GPT-5.5 | 300–1600 | — | — |
| GPT-5.4 | 400–2000 | — | — |
| GPT-5.4-mini | 1200–7000 | — | — |
| GPT-5.3-Codex | 600–3000 | 200–1200 | 400–1000 |

### Business — Codex CLI

Same per-seat limits as Plus, plus larger cloud-task VMs and admin controls. Pay-per-token via API pricing for overflow.

### Enterprise / Edu — Codex CLI

No fixed rate limits — usage scales with **credits** (flexible pricing). Per-seat usage limits match Plus for plans without flexible pricing.

### API Key — Codex CLI

| Model | Local messages | Cloud tasks | Code reviews |
|---|---|---|---|
| GPT-5.5 | Not available | — | — |
| GPT-5.4 | Usage-based (API rates) | — | — |
| GPT-5.4-mini | Usage-based (API rates) | — | — |
| GPT-5.3-Codex | Usage-based (API rates) | — | — |

> **GPT-5.5 is not available on API-key auth in Codex CLI.** ChatGPT plans only.

---

## Credit-based pricing (Business & new Enterprise — token rate card)

Credits are the workspace pricing unit; rates below are **credits per 1M tokens**.

| Model | Input | Cached input | Output |
|---|---:|---:|---:|
| GPT-5.5 | 125 | 12.50 | 750 |
| GPT-5.4 | 62.50 | 6.25 | 375 |
| GPT-5.4-mini | 18.75 | 1.875 | 113 |
| GPT-5.3-Codex | 43.75 | 4.375 | 350 |
| GPT-5.2 | 43.75 | 4.375 | 350 |
| GPT-5.3-Codex-Spark | — | — | — |
| GPT-Image-2 (image) | 200 | 50 | 750 |
| GPT-Image-2 (text) | 125 | 31.25 | 250 |

> Cloud tasks and code review run on `gpt-5.3-codex`.

## Credit-based pricing (Plus / Pro / existing Enterprise+Edu / new Edu — message rate card)

Approximate **credits per message** (legacy rate card; useful for rough planning):

| Action | GPT-5.5 | GPT-5.4 | GPT-5.3-Codex | GPT-5.4-mini |
|---|---:|---:|---:|---:|
| Local task (1 message) | ~14 | ~7 | ~5 | ~2 |
| Cloud task (1 message) | — | — | ~25 | — |
| Code review (1 PR) | — | — | ~25 | — |
| Image generation 1024×1024 | ~5–6 (any model) | | | |
| Image generation 1024×1536 | ~7–8 (any model) | | | |

> These averages also apply to GPT-5.2.

---

## Speed modes

### Fast mode (`/fast on`)

1.5× faster output, higher credit consumption. Available in CLI, IDE, and the Codex app when signed in with ChatGPT.

| Model | Speed multiplier | Credit multiplier |
|---|---:|---:|
| GPT-5.5 | 1.5× | 2.5× |
| GPT-5.4 | 1.5× | 2× |

> With API-key auth, Fast mode credits don't apply — you pay standard API rates.

### GPT-5.3-Codex-Spark (separate model)

Optimized for near-instant real-time iteration. **ChatGPT Pro only**, research preview. Not the same as Fast mode — it's a different model with its own usage limit.

---

## Practical: mapping `codext --max-tokens` to a $ budget

`codext --max-tokens` caps **total tokens across all iterations** (input + output + reasoning). For users on **API key** auth, this directly maps to dollars. The math:

```text
$ per 1M total tokens ≈ (input_share × input_price) + (output_share × output_price)
                       + (cached_share × cached_price)
```

For typical Codex sessions (lots of context-reading + medium output, no caching):

### 60% input / 40% output mix

| Model | $ per 1M total tokens | $5 budget → tokens | $10 budget → tokens | $25 budget → tokens |
|---|---:|---:|---:|---:|
| gpt-5.4-nano | $0.620 | ~8.1M | ~16.1M | ~40.3M |
| gpt-4.1-mini | $0.880 | ~5.7M | ~11.4M | ~28.4M |
| gpt-5.4-mini | $2.250 | ~2.2M | ~4.4M | ~11.1M |
| gpt-5.2 / gpt-5.2-codex | $6.650 | ~752k | ~1.5M | ~3.8M |
| gpt-5.4 | $7.500 | ~667k | ~1.3M | ~3.3M |
| gpt-5.5 | $15.000 | ~333k | ~667k | ~1.7M |

### 50% input / 50% output mix

| Model | $ per 1M total tokens | $5 → tokens | $10 → tokens | $25 → tokens |
|---|---:|---:|---:|---:|
| gpt-5.4-nano | $0.725 | ~6.9M | ~13.8M | ~34.5M |
| gpt-4.1-mini | $1.000 | ~5.0M | ~10.0M | ~25.0M |
| gpt-5.4-mini | $2.625 | ~1.9M | ~3.8M | ~9.5M |
| gpt-5.2 / gpt-5.2-codex | $7.875 | ~635k | ~1.3M | ~3.2M |
| gpt-5.4 | $8.750 | ~571k | ~1.1M | ~2.9M |
| gpt-5.5 | $17.500 | ~286k | ~571k | ~1.4M |

### 30% input / 70% output mix (output-heavy refactor / codegen)

| Model | $ per 1M total tokens | $5 → tokens | $10 → tokens | $25 → tokens |
|---|---:|---:|---:|---:|
| gpt-5.4-nano | $0.935 | ~5.3M | ~10.7M | ~26.7M |
| gpt-4.1-mini | $1.240 | ~4.0M | ~8.1M | ~20.2M |
| gpt-5.4-mini | $3.375 | ~1.5M | ~3.0M | ~7.4M |
| gpt-5.2 / gpt-5.2-codex | $10.325 | ~484k | ~969k | ~2.4M |
| gpt-5.4 | $11.250 | ~444k | ~889k | ~2.2M |
| gpt-5.5 | $22.500 | ~222k | ~444k | ~1.1M |

> Reality check: codex CLI runs are usually input-heavy because the model reads files. A 60/40 (input/output) mix is a reasonable default. Add a 20% safety margin to whatever number you pick.

### Suggested `codext` invocations by spend target

```bash
# ~$5 cap on gpt-5.4-mini (cheap dev loop, 4-5 iterations)
codext -p "..." -m 5 --model gpt-5.4-mini --max-tokens 2000000

# ~$10 cap on gpt-5.4 (balanced quality/cost)
codext -p "..." -m 5 --model gpt-5.4 --max-tokens 1300000

# ~$20 cap on gpt-5.5 (max quality, ChatGPT-auth only)
codext -p "..." -m 5 --model gpt-5.5 --max-tokens 1300000

# ~$50 cap on gpt-5.5 with full-blown reviewer pass
codext -p "..." -m 10 --model gpt-5.5 --max-tokens 3300000 \
       -r "Run npm test and npm run lint, fix any failures"
```

> **Important caveat:** Codex CLI's JSONL stream emits token counts but **never dollar amounts**. `codext` therefore enforces the cap by token count, not directly by dollars. The conversion above is your responsibility — re-verify against [platform.openai.com/docs/pricing](https://platform.openai.com/docs/pricing) before treating the dollar columns as gospel.
>
> **ChatGPT plan users (Plus / Pro / Business with included usage):** dollars per token aren't the right mental model. You're metered by **messages per 5-hour window** (or **credits** for Business / new Enterprise). Use `codext -m <runs>` to cap iterations instead. Run `/status` inside an interactive `codex` session to see remaining limits.

---

## Tips to stretch your budget further

Straight from OpenAI's pricing FAQ:

1. **Be precise with prompts.** Strip out unnecessary context — `codext` already injects iteration scaffolding for you, so keep your `-p` prompt focused.
2. **Trim `AGENTS.md`.** Every Codex turn ingests it. [Nest project-specific instructions](https://developers.openai.com/codex/guides/agents-md#layer-project-instructions) instead of loading them globally.
3. **Limit MCP servers.** Each enabled MCP adds context to every message. Disable unused ones.
4. **Use a smaller model for routine work.** `gpt-5.4-mini` is dramatically cheaper than `gpt-5.5` and often plenty for boilerplate or small bug fixes.
5. **Avoid Fast mode for long iterative loops.** Fast mode burns credits 2–2.5× faster. Save it for interactive sessions where latency matters.
6. **Watch cached input.** `codext` uses `--full-auto` and re-reads files between iterations; cached input prices (10× cheaper than fresh input) help — keep your repo layout stable across iterations to maximize cache hits.

---

## Where to monitor live usage

- ChatGPT plans: [Codex usage dashboard](https://chatgpt.com/codex/settings/usage)
- Inside an interactive `codex` session: type `/status`
- API key: [platform.openai.com/usage](https://platform.openai.com/usage)
- `codext` itself: every iteration prints `🔢 Iteration tokens: X (running total: Y)` — the running total caps via `--max-tokens`.
