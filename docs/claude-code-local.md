# Lane 2b: Claude Code on a local model (via Unsloth)

The kit's reference harness is Hermes. This lane is the alternative that
keeps your *daily* harness: Claude Code itself, pointed at a local
server. When the cloud is down you keep your muscle memory — same CLI,
same tools, same keybindings — only the model underneath changes.

Verified 2026-09-14 on the reference setup (M4 Pro, 24 GB,
`gpt-oss-20b`): a 3-turn agentic extraction task ran end to end —
tool call, a permission refusal, self-correction, clean JSON answer.

## Why this lane exists (a real measurement, not vibes)

We ran the *same* 20B model on the *same* 10-field extraction bench
(a public SEC document, scored against a fixed golden set) through
three harnesses:

| harness | overhead | score |
|---|---|---|
| ~30-line agent loop | ~0 tokens | 8/10 |
| Hermes | ~16k tokens | 0/10 (15 attempts, 3 models) |
| Claude Code → local server | ~15k tokens | **9/10** |

Same model, same weight class of harness context, opposite outcomes.
The variable is harness *quality*, not size: Claude Code's tool schemas
look like what the model saw in training, its refusals read as
actionable feedback ("permission not granted" → the model rerouted and
answered inline), and the serving layer below repairs malformed
tool-call syntax. A persona-style harness at the same token weight
loses the task after the first tool turn.

Two honest caveats from the bench: one point of that 9/10 came from
scorer leniency (a partial answer that substring-matched the golden),
and the serving layer's tool-call healing means this measures
harness+server as a system. The 0-vs-9 gap stands either way.

## One command

```bash
./lane-claude.sh                 # server + Claude Code on the local model
./lane-claude.sh --server-only   # server only, then: hermes --in <dir>
pkill -f 'unsloth run'           # stop the server when the cloud is back
```

Unsloth generates a new API key on every start and has no flag to pin
it. The script starts the server, waits for the key to appear in the
server's own log (`~/.unsloth/studio/logs/server/`), hands it to Hermes
if Hermes is installed, and launches Claude Code with MCP disabled. The
key is never printed. Model, GGUF variant, context and extra flags come
from `KIT529_UNSLOTH_MODEL`, `KIT529_GGUF_VARIANT`, `KIT529_CTX` and
`KIT529_UNSLOTH_FLAGS`. Drilled 2026-09-28: server ready in 34 s warm,
first Claude Code answer in 73 s including its startup.

The steps below are what the script does, for when you want to run them
by hand.

## Ollama only, no Unsloth

If Ollama is already on the machine (the kit's reference), Claude Code can use it directly: Ollama
serves an Anthropic-compatible `/v1/messages`, no key needed.

```bash
KIT529_ENGINE=ollama ./lane-claude.sh                       # gpt-oss:20b, context 32K
KIT529_ENGINE=ollama KIT529_OLLAMA_MODEL=qwen3:14b ./lane-claude.sh
```

The one trap: Ollama's default context is 4 096 tokens and Claude Code's system prompt alone is
larger, so the first attempt answered a question nobody asked. The script creates a variant
(`gpt-oss:32768ctx`, same blob on disk, `num_ctx` raised) and uses that. Verified 2026-10-14 on
`gpt-oss:20b`: first answer in 44–58 s including model load; a three-turn tool task (list files,
write a file, answer) in 61 s. Claude Code prints an `unrecognized_model` notice for the custom
name; it is harmless.

Unsloth stays the reference engine because the same server also drives the Hermes lane; the Ollama
path is for machines that will only ever run lane 2b.

## Setup

1. **Install Unsloth Studio** (serves GGUF models behind an
   Anthropic-compatible `/v1/messages` endpoint; bundles llama.cpp):

   ```bash
   curl -fsSL https://unsloth.ai/install.sh | sh
   ```

   User-space install (`~/.unsloth`, ~1.6 GB), no launch agents. Add
   `UNSLOTH_NO_TORCH=1` before the `sh` to skip the training stack —
   this lane only needs inference.

2. **Start the server** (downloads the model on first run, ~11 GB):

   ```bash
   unsloth run --model unsloth/gpt-oss-20b-GGUF --max-seq-length 65536 \
     -np 1 --api-only --disable-tools -p 8888
   ```

   It prints an API key when the model is loaded. Flags that matter:

   - `-np 1` — llama-server defaults to 4 parallel slots and each slot
     gets context/4. One slot = the whole 64K for your session.
   - `--api-only` — no web UI, just the endpoint.
   - `--disable-tools` — kills the server-side web-search/code-exec
     tools. Claude Code brings its own; you don't want two sets.
   - Binds to localhost only by default. Keep it that way.

3. **Point Claude Code at it** (new terminal):

   ```bash
   export ANTHROPIC_BASE_URL="http://localhost:8888"
   export ANTHROPIC_AUTH_TOKEN="<the key unsloth printed>"
   export CLAUDE_CODE_ATTRIBUTION_HEADER=0
   claude --model unsloth/gpt-oss-20b-GGUF \
     --strict-mcp-config --mcp-config <(echo '{"mcpServers":{}}')
   ```

   Or let `unsloth start claude` wire all of the above for you (the
   manual path is what we verified; the wrapper is the same wiring).

## Which model

The reference numbers above are for `gpt-oss-20b`. A later bench
(2026-09-14, same 10-field extraction task) is worth knowing before you
pick: the 20B scored 0/10 through Hermes across 15 attempts, while
`unsloth/gemma-4-26B-A4B-it-GGUF` at `UD-Q3_K_XL` was the only model
that survived both harnesses, 10/10 through Hermes and 7/10 strict (about
10 by a human reading) through Claude Code. If you want one resident
model for both lanes, that is the one, with two flags that matter:

```bash
KIT529_UNSLOTH_MODEL=unsloth/gemma-4-26B-A4B-it-GGUF KIT529_GGUF_VARIANT=UD-Q3_K_XL \
KIT529_CTX=32768 KIT529_UNSLOTH_FLAGS="--speculative-type off" ./lane-claude.sh
```

Its GGUF bundle ships a draft model and a vision projector that
llama.cpp loads by default; with a 64K context that put a 24 GB machine
into swap at 1.2 tok/s. `--speculative-type off` and a 32K context bring
it to about 40 tok/s decode, 100+ tok/s prefill.

## Eight tasks, scored by code

`bench/l1bench.py` runs eight outage-grade tasks (shell one-liner, JSON extraction, translation,
small code fix, alert summary, tool-call JSON, regex, mail labels) against any OpenAI-compatible
endpoint and grades every answer in code. Reference machine, 2026-10-14, each model alone in memory:

| | gpt-oss:20b (Ollama) | gemma-4-26B UD-Q3 (Unsloth) |
|---|---|---|
| score | 8/8 | 7/8 |
| total time | 74 s | 191 s (289 s with a 6 000-token cap) |
| tokens per second | ~39 | ~37 |
| failure | — | shell one-liner: never left its reasoning, empty answer even at 6 000 tokens |

Same speed, different reasoning length: gemma thinks two to seven times longer per task. Together
with the extraction bench above (gpt-oss 9/10 in Claude Code, 0/10 in Hermes; gemma 7/10 and
10/10), the choice is per lane: gpt-oss for Claude Code and direct questions, gemma where Hermes and
MCP tools are involved. If a reasoning model returns nothing on a terse prompt, raise
`L1_MAX_TOKENS` or ask again with "answer in one line, no reasoning".

## The gotchas, learned so you don't have to

- **Disable MCP servers.** Non-negotiable on a 64K local context: a
  fleet of MCP tool schemas adds tens of thousands of tokens on top of
  Claude Code's own ~15k and drowns a 20B. MCP work is the Hermes
  lane's job (see `mcp/`), with a hand-picked, tier-limited server.
- **`CLAUDE_CODE_ATTRIBUTION_HEADER=0`.** The header changes per
  request and invalidates llama.cpp's prefix cache — up to 90% slower
  without this.
- **Don't run this next to Ollama.** Two 13 GB residents don't fit in
  24 GB. One server at a time.
- **Your Ollama model blob won't feed llama.cpp.** Ollama writes the
  GGUF architecture key in its own dialect (`gptoss` where upstream
  expects `gpt-oss`), so the "it's all just GGUF" shortcut fails and
  the model downloads twice. Annoying, known, not a bug in your setup.
- **Expect per-turn prefill.** In our runs the prefix cache did not
  carry between turns: ~45 s of prefill per turn at 20k context
  (~470 tok/s prefill, 45–55 tok/s decode on the reference hardware).
  Usable, not snappy.

## Ceiling

Same model, same ceiling as the rest of the kit: capable L1 operator,
not a detective (see the README's honest-ceiling section). What this
lane adds is not intelligence — it's that the harness stops being the
thing that kills the task, and the workflow you already know keeps
working offline.
