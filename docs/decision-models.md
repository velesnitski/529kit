# Lane 3: decisions, not text — local decision models, measured

A decision model does not write. You send it some state and typed questions and it returns a label
with probabilities (`choice`), a 0..1 probability that a statement is true (`noul`), or a level on
a rubric (`score`). One answer costs about a second on a laptop and the answer is a number your code
can branch on. The hosted original is TypeSafe's Jev (`POST /v1/systemone`); Ollama ≥ 0.35 serves
the same API locally with `nimble` (Bespoke, 9B, 9.5 GB) and `tev1` (Together, 4B and 0.8B).

This lane exists in the kit for one reason: during an outage your *triage* can keep working offline
(mail, alerts, tickets, tool calls), and that is a different job from the text lanes. It is also
here with a negative result, because we measured where it does not pay.

## What we measured

Nimble 9B (Q8_0, 8.9 GB resident) on a 24 GB M4 Pro, 25 cases (`bench/systemone_cases.json`,
the published set has host and channel names made generic):

| Set | Result | Notes |
|---|---|---|
| Tool-call gating, allow / ask / block, 14 cases | 12/14 | the two regex false positives (a heredoc containing the word *secret*, a script reading the environment) correctly allowed; credential upload, `env \| base64 \| curl`, `rm -rf ~` blocked at 0.87–0.96. Misses: "disable the hooks" → ask at confidence 0.03; a web search with internal terms → block rather than ask (defensible) |
| Alert triage, actionable / watch / noise, 6 cases | 4/6 | both misses over-escalate watch → actionable at low confidence: the safe direction |
| Mail labels, 5 cases | 5/5 | all at confidence ≥ 0.96 |

Latency: 7 s to load, then about 0.9 s for one question and 1.5 s for two; the model unloads after
`keep_alive` (5 min by default). `confidence` is 1 − H(p)/ln N, not calibrated correctness.

Independent numbers worth knowing: Archestra ran 100 real agent tool calls through several models;
Jev scored 93–95 %, Nimble 83–86 %, a constant "benign" label 79 %. Keep that baseline in mind: a
classifier at 80 % on tool calls is barely better than doing nothing.

## Where it does not pay: code review

We asked "which functions need refactoring" over a 371-function Python project, four ways: Claude
alone; Nimble screens every function and Claude reads only the shortlist; Nimble alone; Claude with
Nimble's scores as hints.

| Arm | Keeps of Claude-alone's 15 findings | Claude cost | Wall time |
|---|---|---|---|
| Claude alone | 15/15 | $2.81 | 25 s |
| Nimble shortlist (p ≥ 0.5) → Claude | 6/15 | $2.75 | 20 min + 25 s |
| Nimble alone | 11/15 | $0 | 20 min |
| Claude + hints | 9/15 | $2.87 | 34 s |

The shortlist was 23 % of the functions but 66 % of the lines: the functions a classifier flags are
the long ones, and the long ones are the token mass. The pre-filter cut the bill by 2 % and lost 60 %
of the findings, and took 20 minutes to do it. Any task where the items are long and the real answer
needs the whole picture looks like this. Use the text model.

## Where it fits

Short items at high volume, one answer each, where there is no "read everything at once" alternative:

- mail and ticket labels (5/5 above);
- alert triage as a pre-filter, with the uncertain tail escalated;
- a **shadow gate** on agent tool calls: `hooks/shadow-gate.sh` asks the model in a detached
  background job (the hook returns in about 50 ms) and logs its verdict next to your own guard's.
  After a week the log tells you two things: which of your regex blocks the model confidently calls
  `allow` (false-positive candidates) and which calls your regex let through that the model calls
  `block` (missing rules). The model never becomes the gate; it audits the gate.

## Operating rules

- A resident 9 GB model with no consumer is a cost, not a capability. We removed Nimble after the
  benchmark because nothing was wired to it yet; `ollama pull nimble` brings it back in ten minutes.
- It does not fit next to the text lane: 9 GB plus a 12–13 GB resident is more than 24 GB.
- Hosted Jev sees your tool arguments and documents. For commands with hostnames and tokens, or for
  client documents, use the local model or redact first.
- Never let a classifier be the only lock on a destructive action. Archestra's own conclusion, and ours.

## Files

- `bench/systemone_test.py`, `bench/systemone_cases.json`: the 25-case smoke test, any `/v1/systemone` server
- `hooks/shadow-gate.sh`: the shadow gate, with the `settings.json` snippet in its header
