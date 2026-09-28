# ADR 0005: One-command launcher for lane 2b, key captured from the server log

Date: 2026-09-28
Status: accepted

## Context

Lane 2b (ADR 0004) was three manual steps: start the Unsloth server,
copy the API key it prints, export three variables and start Claude
Code. During a real outage the copy step is the one people fumble, and
the key changes on every server start: Unsloth generates it per run and
offers no flag to pin it (`--api-key-name` is only a label).

The key is also written to the server's own log
(`~/.unsloth/studio/logs/server/server-<ts>-pid<pid>.log`, line
`API Key: sk-unsloth-...`), a few seconds after the model loads.

A second field result since ADR 0004: on the 2026-09-14 bench the
20B reference model scored 0/10 through Hermes, while
`gemma-4-26B-A4B-it` (UD-Q3_K_XL) was the only model that survived both
harnesses (10/10 Hermes, 7/10 strict through Claude Code). Its GGUF
bundle ships a draft model and a vision projector that llama.cpp loads
by default; with a 64K context that pushed a 24 GB machine into swap
(1.2 tok/s). `--speculative-type off --max-seq-length 32768` restored
40 tok/s.

## Decisions

1. **`lane-claude.sh`**: start the server in the background, wait for a
   log file newer than a marker created before the start (so a stale key
   from an earlier run is never picked), read the key from it, hand it to
   Hermes when Hermes is installed, launch Claude Code with MCP disabled.
   `--server-only` stops after the Hermes step. Refuses to start next to
   a running Ollama.
2. **The key is never printed.** It lives in the process environment of
   the launched Claude Code and in Hermes' config, both local.
3. **Model choice stays configurable** (`KIT529_UNSLOTH_MODEL`,
   `KIT529_GGUF_VARIANT`, `KIT529_CTX`, `KIT529_UNSLOTH_FLAGS`); the
   reference default stays the 20B so the documented numbers hold, and
   the lane doc records the gemma result and the bundle-trap flags for
   readers who choose that model.
4. Lint gates extend to the new script.

## Consequences

- The outage path is one command, drilled: server ready in about 35 s
  warm on the reference hardware, Claude Code's first answer within about
  75 s including its own startup.
- The script depends on Unsloth's log location and key format. If either
  changes the script fails closed after `KIT529_WAIT` seconds and points
  at the newest log; the manual path in the lane doc still works.
