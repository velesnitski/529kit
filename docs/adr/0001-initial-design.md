# ADR 0001: Initial design of 529kit

Date: 2026-09-04
Status: accepted

## Context

Cloud LLM assistants are now load-bearing in daily engineering work, and they
fail: provider overloads (HTTP 529), full outages, and networks where the
cloud is unreachable at all. Most "run an LLM locally" material covers
installation and stops — nothing covers the moment that matters: *is the
fallback actually going to work when the primary is gone?*

The kit's content was extracted from a real end-to-end exercise: local
harness + 20B model driving a production read-only MCP server, compared
against a frontier cloud model on the same tools.

## Decisions

1. **Name: `529kit`.** Unique on GitHub at creation time; instantly readable
   by the target audience. Rejected: an `ollama`-prefixed name (marries the
   kit to one layer of the stack and reads as vendor tooling), and generic
   words (`lifeboat`, `ripcord`, `cloudless` — all taken by starred
   projects; `candle` collides with a major ML framework).

2. **Ollama is the base layer; Hermes is the reference harness, not a
   dependency.** Any OpenAI-compatible client works. Kit ideas (drill,
   scaffolding, server-side gates) are harness-agnostic.

3. **Drill-first philosophy.** `drill.sh` is the core artifact, not
   `install.sh`. A fallback is defined by its rehearsal: measured cold
   start, fail-closed checks, end-to-end agent smoke test — while the
   cloud is still up.

4. **Honesty about the ceiling is a feature.** The README documents what a
   20B reliably does and reliably fails at, from observed behavior. This is
   deliberately contrarian to local-AI hype and is the kit's credibility.

5. **Security posture:** secrets never enter the repo, the harness config,
   or wrapper scripts; read-only enforcement belongs to the MCP server
   process (env gate), never to model behavior; wrappers fail closed.

6. **Pinned reference setup** (verified): Ollama 0.32.x, Hermes 0.20.x,
   `gpt-oss:20b`, Apple Silicon 24 GB. Version drift is expected;
   `doctor.sh` exists to catch it.

## Consequences

- Examples use a fictional `acme-mcp`; no real infrastructure identifiers
  appear anywhere in the repo.
- Hermes evolves quickly; docs may rot. Mitigation: pins + doctor + the
  scripts print what they do.
- Scope of v0.1 is deliberately one-evening small: README, three scripts,
  runbook template, MCP recipe, prompt scaffolding.
