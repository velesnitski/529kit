# ADR 0004: Second local lane — Claude Code on an Unsloth server

Date: 2026-09-14
Status: accepted

## Context

The kit shipped with one local harness (Hermes). Field benchmarking
showed a hard failure class: small models (14B–30B) lose the task after
the first tool turn inside Hermes' ~16k-token system context — 0/10
across 15 attempts and 3 models on a fixed extraction bench, while the
same models score 8/10 bare or in a ~30-line loop.

A new measurement changed the picture: the same 20B model driven by
Claude Code headless, pointed at a local Unsloth/llama.cpp server
(Anthropic-compatible `/v1/messages`), scored 9/10 on the same bench at
the same ~15k-token harness weight — including recovering from a
permission refusal mid-task.

## Decisions

1. **Add Claude Code + Unsloth as lane 2b** (`docs/claude-code-local.md`),
   keeping Hermes as the MCP lane. Roles, not ranking: Claude Code lane
   for agentic file work with the user's daily muscle memory; Hermes
   lane for wired MCP servers.
2. **Document the refined harness finding**: harness *quality* at a
   given weight — schema familiarity, actionable refusals, server-side
   tool-call healing — is the variable that sinks or carries small
   models, not the token overhead itself.
3. **Record the GGUF portability trap**: Ollama blobs declare
   architecture `gptoss`; upstream llama.cpp expects `gpt-oss`.
   Cross-runtime blob reuse fails; the model is downloaded twice by
   design.
4. **No new drill script yet.** The manual path is verified end to end;
   a scripted drill (`drill.sh` extension) waits until the lane has
   been exercised beyond one bench task, per the kit's own
   drill-before-trust rule.

## Consequences

- README gains the lane row and a pointer; the Hermes FAQ answer is
  now backed by a measured cross-harness comparison.
- Two servers must not run concurrently on 24 GB machines; the lane
  doc says so explicitly.
