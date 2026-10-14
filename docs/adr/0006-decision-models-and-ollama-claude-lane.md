# ADR 0006: Decision models as a measured third lane; Claude Code on Ollama without Unsloth; an auto-scored drill

Date: 2026-10-14
Status: accepted

## Context

Three things happened since ADR 0005.

1. Ollama 0.35 added `/v1/systemone`, the decision-model API from TypeSafe's Jev, with local
   models (`nimble`, `tev1`). We tested whether such a model earns a place in an outage kit: a
   25-case smoke test (tool-call gating, alert triage, mail labels), a shadow hook that logs the
   model's verdict next to a regex guard, and a four-arm benchmark on "which functions need
   refactoring" over a 371-function project.
2. Claude Code can talk to Ollama's Anthropic-compatible `/v1/messages` directly. The first attempt
   produced nonsense: Ollama's default context of 4 096 truncates Claude Code's system prompt. A
   model variant with `num_ctx 32768` fixed it; tool use (list files, write a file, answer) ran in
   three turns, 61 s, on `gpt-oss:20b`.
3. Choosing the resident model had been done on one extraction bench. Eight outage-grade tasks,
   each checked by code, gave a second data point: `gpt-oss:20b` 8/8 in 74 s, `gemma-4-26B` 7/8 in
   191 s at the same tokens per second, gemma running away in reasoning on a terse one-line prompt.

## Decisions

1. **Lane 3, documented, not adopted.** `docs/decision-models.md` records what the model is good
   for (short items at volume, a shadow audit of a guard) and the negative result on code review
   (shortlist = 23 % of functions but 66 % of lines; bill −2 %, findings −60 %, 20 minutes). The
   smoke test and the shadow gate ship so a reader can repeat the measurement; the model itself
   is not part of `install.sh`, and we removed it from the reference machine because nothing
   consumed it.
2. **`KIT529_ENGINE=ollama` in `lane-claude.sh`.** Lane 2b without Unsloth: start Ollama, create
   `<model>:<ctx>ctx` with `num_ctx` raised, launch Claude Code against `localhost:11434` with any
   bearer value. Unsloth stays the reference engine because it serves Hermes too.
3. **`bench/l1bench.py`** joins the drill: eight auto-scored tasks against any OpenAI-compatible
   endpoint, numbers kept per model. The README's model table now says which model survived which
   harness instead of ranking them.

## Consequences

- Two engines for lane 2b; the Ollama path has one more trap (context) and the script sets it.
- Model advice becomes per lane: the model that works under Hermes with MCP tools is not the one
  that answers fastest in Claude Code. Readers pick by the lane they will actually use.
- Published cases are generic (hosts, channels, vendors); the numbers come from the same cases
  with the names changed, and say so.
