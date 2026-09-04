# ADR 0003: Drill the cloud fallback tier too

Date: 2026-09-04
Status: accepted

## Context

Tier 1 of the plan (a second cloud via OpenRouter) was field-tested the same
way the local tier was. The result flipped the on-paper ranking: the model
we favored by lineage reputation returned HTTP 429 on every attempt (its
free tier was overloaded), while a less-hyped model answered correctly in
3.5 seconds. A fallback that is itself overloaded misses the point.

## Decisions

1. **`drill.sh` gains an optional step [4]:** if `KIT529_CLOUD_MODEL` is
   set (provider override via `KIT529_CLOUD_PROVIDER`, default
   `openrouter`), the drill runs a timed end-to-end call through the
   harness against the cloud tier. A failure is a **warning**, not a drill
   failure — the local tier is the layer that must never depend on anyone.

2. **README documents the two field lessons:** reputation is not
   availability (pick the fallback model by drilling, not by leaderboard),
   and `:free` endpoints may log/train on prompts (sensitive work stays
   local or paid).

3. **The kit still handles no keys.** Provider credentials belong to the
   harness (`hermes login` / its env), never to 529kit scripts or repo.

## Consequences

- Choosing a cloud fallback model becomes an empirical act with a number
  attached, consistent with the kit's drill-first philosophy.
- The drill's exit code stays meaningful for the layers the kit owns.
