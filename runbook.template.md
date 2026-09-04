# <YOUR NAME>'s cloud-down runbook

> Fill this in, keep it as a plain file on disk, and print the path into your
> memory: the runbook must survive the outage it describes. If your only copy
> of "what to do when the AI is down" lives in the AI — you don't have one.

Last drill: <DATE>  (cold start: <N>s, warm: <N>s — from ./drill.sh)

## 0. Don't switch yet
- Provider status page: <URL, e.g. status.anthropic.com>
- Most overload windows are minutes. Your cloud CLI probably retries by itself.
- Try a smaller cloud model tier first: <YOUR COMMAND, e.g. /model sonnet>

## 1. Second cloud (survives a single-provider outage)
- <YOUR SETUP: e.g. hermes fallback add + OpenRouter key — configured? Y/N>
- If not configured: this is your biggest gap. Ten minutes, once.

## 2. Fully local (survives everything)
```bash
hermes --in <YOUR PROJECT DIR>        # interactive
hermes -z "question" --in <DIR>       # one-shot
```
- First reply pays ~<N>s model load. For a long incident:
  `export OLLAMA_KEEP_ALIVE=2h`
- Good for: drafts, translations, shell one-liners, single-file edits,
  fixed tool scenarios with scaffolded prompts (see prompts/).
- NOT for: multi-step investigation. That work waits for the cloud.

## 2a. Local agent + your MCP servers (optional)
- Wired servers: <LIST, e.g. "monitoring (read-only, core tier)">
- Wrappers live in: <PATH>   Secrets live in: <PATH, chmod 600>
- On token rotation also update: <SECRET FILE PATHS>
- Intranet MCPs need the VPN up. Error signature of a VPN/DNS flap:
  "nodename nor servname provided, or not known" — check VPN first.
- Proven prompts for your servers: <PATHS or paste them here>

## Environment facts (fill after ./drill.sh)
- Machine: <MODEL, RAM>
- Model: <NAME, SIZE> — max sensible for this RAM: <Y/N>
- OLLAMA_CONTEXT_LENGTH: <VALUE> (unset = 4096; too small for MCP)
  - NOTE (macOS): `launchctl setenv` does NOT survive reboot — re-run after restart.
- Ollama app autostarts on login: <Y/N>

## What does NOT fail over (accept this now, not mid-incident)
- <e.g. cloud-assistant memory, org MCP fleet, CI helpers>
