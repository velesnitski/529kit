# Prompt scaffolding for small models

A 20B-class model is a capable L1 operator with no initiative. It executes
what the prompt encodes and trusts every tool result literally. These five
rules are the difference between a finished answer and a raw tool-call JSON
dumped at you mid-loop (yes, that's the observed failure mode).

## The five rules

1. **Name the exact tools, in order.** "Call `diagnose_host`, then
   `get_active_problems`" — not "investigate the host".
2. **Name the exact argument names.** Small models invent plausible ones
   (`host_name` instead of `host`), hit a validation error, and do not
   recover. Spell them out: *"the argument name is `host`"*.
3. **Demand a plain-text final answer and forbid JSON.** Literally:
   *"After the tool calls you MUST write a final plain-text answer. Do not
   output tool-call JSON as your answer."*
4. **Bound the output.** "3 lines max", "problems listed by age". Unbounded
   asks drift.
5. **One task per prompt.** Chain scenarios yourself; don't ask the model to.

## Template

```
Investigate <TARGET> using <SERVER> tools: call <TOOL_A> (the argument
name is '<ARG>'), then <TOOL_B> with <ARG>=<VALUE>. After the tool calls
you MUST write a final plain-text answer: 1) <fact one>, 2) <fact two>,
3) one-paragraph conclusion. Do not output tool-call JSON as your answer.
```

## Worked example (monitoring triage)

```
hermes -z "Investigate host <HOST> using monitoring tools: call
diagnose_host (the argument name is 'host'), then get_active_problems
with severity_min=4. After the tool calls you MUST write a final
plain-text answer: 1) problems listed by age, 2) traffic status,
3) one-paragraph conclusion. Do not output tool-call JSON as your answer."
```

Observed on `gpt-oss:20b`: with this scaffolding — complete, accurate
run in ~2 minutes. Without rule 2 — dead on the first validation error.

## Know what you'll still miss

Even a perfect scaffold won't make a small model *suspicious*. In our field
test it accepted "problem started 8 minutes ago" at face value; the larger
cloud model noticed the same problem had "just started" twice in 40 minutes,
made one extra call, and found a crash-loop with hundreds of firings a day.
Scaffolds buy you reliable execution — judgment still waits for the cloud.
