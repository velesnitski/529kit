# 529kit

> When the cloud says 529, your machine keeps working.

A local AI **fallback kit**: [Ollama](https://ollama.com) + a small open-weights model + the [Hermes agent harness](https://github.com/NousResearch/hermes-agent), pre-wired, pre-drilled — and honest about what a 20B model can and cannot do.

`529` is the HTTP status Anthropic returns when it's overloaded. It has become shorthand for *"my AI assistant is down and half my workflow with it."* This kit is the plan for that moment — and for planes, blackouts, and networks where the cloud can't reach you at all.

**Core philosophy: a fallback you haven't drilled is a hope, not a plan.**

## Quickstart

```bash
git clone https://github.com/velesnitski/529kit && cd 529kit
./install.sh     # ollama + model + hermes (each step skipped if already present)
./doctor.sh      # health check: server, model, RAM, context, harness
./drill.sh       # rehearse the outage NOW, while the cloud is still up
```

When the cloud actually goes down:

```bash
hermes --in <your-project-dir>       # interactive agent, fully local
hermes -z "your question" --in <dir> # one-shot
```

## What's inside

| File | Purpose |
|------|---------|
| `install.sh` | Idempotent setup: Ollama, model pull, Hermes |
| `doctor.sh` | 30-second health check you can run any time |
| `drill.sh` | The differentiator: timed cold-start + warm run + end-to-end agent test, **before** you need it |
| `runbook.template.md` | Fill-in outage runbook — keep it on disk, not in the cloud |
| `mcp/` | Wire your MCP servers into the local agent without leaking secrets |
| `prompts/` | Prompt scaffolding that small models actually need |

## Pick a model for your RAM

| RAM | Model | What to expect |
|-----|-------|----------------|
| 8 GB | `llama3.2:3b`, `qwen3:4b` | drafts and one-liners only |
| 16 GB | `qwen3:14b` | decent drafts, light tool use |
| 24 GB | `gpt-oss:20b` *(default, reference setup)* | solid L1 work, verified below |
| 48 GB+ | `gpt-oss:120b`, `qwen3:32b` | approaching junior-cloud quality |

*(Model names as of 2026-09; check `ollama search` for current tags.)*

## The honest ceiling

This section is the part most local-AI guides skip. Field-tested on `gpt-oss:20b` (M4 Pro, 24 GB), driving real MCP tools:

**Reliably works:**
- Drafts, translations, summaries, shell one-liners, single-file edits
- Fixed tool-calling scenarios **with scaffolded prompts** (see `prompts/`)
- Extracting and organizing facts returned by tools — accurately

**Reliably fails:**
- Unscaffolded tool calls — it invents argument names, hits a validation error, and dies without recovering
- Noticing that data contradicts itself (it trusts tool output literally)
- Making a follow-up call the task didn't explicitly ask for — i.e. actual investigation

Treat it as a **capable L1 operator, not a detective**. Scope your outage plans accordingly: triage locally, investigate when the cloud is back.

## The three-tier plan

1. **Tier 0 — don't switch yet.** Check the provider status page; most 529 windows are minutes. Try a smaller cloud model tier first.
2. **Tier 1 — a second cloud.** An Anthropic outage is not an internet outage. A single OpenRouter key in `hermes fallback add` gets you frontier-class quality from other providers. Cheap, ten minutes, do it once. Two lessons from field-testing this tier:
   - **Reputation is not availability.** Our on-paper favorite `:free` model returned HTTP 429 on every attempt while an unhyped one answered correctly in 3.5 s. Pick your fallback model by drilling it (`KIT529_CLOUD_MODEL=<model> ./drill.sh`), not by leaderboard.
   - **`:free` endpoints may log and train on your prompts.** Anything sensitive stays on the local tier or paid models; the free tier is for drafts and generic code.
3. **Tier 2 — this kit.** Works when *every* cloud is gone: total outage, air travel, blackout, network cutoff.

## Ground rules learned the hard way

- **Drill before the jump.** Every component must fail closed, and you want the cold-start number (a 13 GB model takes ~a minute to load) *before* the incident.
- **The runbook must survive the outage it describes.** Keep it as a plain file on disk. If your only copy of "what to do when the AI is down" lives in the AI — you don't have a runbook.
- **Small models get scaffolding, not trust.** Exact tool names, exact argument names, explicit output format — in the prompt, every time.
- **Security gates live server-side.** Read-only enforcement belongs in the MCP server (env flag), never in the model's good intentions. See `mcp/README.md`.

## FAQ

**Why Hermes?** It's the reference harness here — self-contained installer, MCP support, works against any OpenAI-compatible endpoint. But Ollama is the base layer: any compatible client works. The kit's ideas (drill, scaffold, server-side gates) are harness-agnostic.

**Why not just use a bigger model?** RAM math. The table above is what actually fits next to your browser and IDE.

**Verified reference setup:** Ollama 0.32.x, Hermes 0.20.x, `gpt-oss:20b`, macOS (Apple Silicon, 24 GB). Linux should work; scripts print what they're doing so drift is debuggable.

## License

MIT
