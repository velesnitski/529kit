#!/usr/bin/env bash
# 529kit lane 2b in one command: start an Unsloth server, catch its per-run API
# key, hand the key to Hermes if present, launch Claude Code on the local model
# with MCP disabled. See docs/claude-code-local.md.
#
#   ./lane-claude.sh                 # server + Claude Code (Unsloth, the reference engine)
#   ./lane-claude.sh --server-only   # server only (then: hermes --in <dir>)
#   KIT529_ENGINE=ollama ./lane-claude.sh   # Claude Code on Ollama instead, no Unsloth (see the doc)
#   pkill -f 'unsloth run'           # stop the server afterwards
#
# Unsloth generates a fresh API key on every start and has no flag to fix it
# (only --api-key-name, a label). The key is printed once and written to the
# server's own log under ~/.unsloth/studio/logs/server/, which is where this
# script picks it up.
set -euo pipefail

MODEL="${KIT529_UNSLOTH_MODEL:-unsloth/gpt-oss-20b-GGUF}"
VARIANT="${KIT529_GGUF_VARIANT:-}"          # e.g. UD-Q3_K_XL; empty = repo default
CTX="${KIT529_CTX:-65536}"
PORT="${KIT529_PORT:-8888}"
EXTRA="${KIT529_UNSLOTH_FLAGS:-}"           # e.g. "--speculative-type off" for bundled-draft models
LOG_DIR="$HOME/.unsloth/studio/logs/server"
WAIT_S="${KIT529_WAIT:-300}"

say()  { printf '\033[1;36m[529kit]\033[0m %s\n' "$*"; }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$*"; }

ENGINE="${KIT529_ENGINE:-unsloth}"          # unsloth (reference) | ollama (no Unsloth needed)

if [[ "$ENGINE" == "ollama" ]]; then
    # Ollama serves an Anthropic-compatible /v1/messages, so Claude Code needs no key, only a model
    # whose context is large enough for its system prompt: the default 4096 truncates it and the
    # model answers nonsense. A variant with num_ctx raised fixes that; it shares the blob on disk.
    OMODEL="${KIT529_OLLAMA_MODEL:-gpt-oss:20b}"
    OCTX="${KIT529_OLLAMA_CTX:-32768}"
    VARIANT="${OMODEL%%:*}:${OCTX}ctx"
    command -v ollama >/dev/null 2>&1 || { warn "ollama not on PATH"; exit 1; }
    command -v claude >/dev/null 2>&1 || [[ "${1:-}" == "--server-only" ]] || { warn "claude not on PATH"; exit 1; }
    pgrep -f "unsloth run" >/dev/null 2>&1 && { warn "an Unsloth server is running; two residents do not fit. Stop it first."; exit 1; }
    if ! curl -s -m 2 http://localhost:11434/api/version >/dev/null 2>&1; then
        say "Starting ollama serve"
        (nohup ollama serve >/dev/null 2>&1 &)
        for _ in $(seq 1 30); do curl -s -m 2 http://localhost:11434/api/version >/dev/null 2>&1 && break; sleep 1; done
    fi
    if ! ollama list 2>/dev/null | grep -q "^${VARIANT}"; then
        say "Creating $VARIANT (num_ctx $OCTX) from $OMODEL"
        MF="$(mktemp)"; printf 'FROM %s\nPARAMETER num_ctx %s\n' "$OMODEL" "$OCTX" > "$MF"
        ollama create "$VARIANT" -f "$MF" >/dev/null; rm -f "$MF"
    fi
    if [[ "${1:-}" == "--server-only" ]]; then
        say "Ollama up with $VARIANT. Stop the model with: ollama stop $VARIANT"
        exit 0
    fi
    say "Launching Claude Code on $VARIANT via Ollama (MCP disabled)"
    ANTHROPIC_BASE_URL="http://localhost:11434" ANTHROPIC_AUTH_TOKEN=ollama CLAUDE_CODE_ATTRIBUTION_HEADER=0 \
        claude --model "$VARIANT" --strict-mcp-config --mcp-config <(echo '{"mcpServers":{}}') "$@"
    say "Model unloads after Ollama's keep-alive; now: ollama stop $VARIANT"
    exit 0
fi

command -v unsloth >/dev/null 2>&1 || { warn "unsloth not on PATH (install: docs/claude-code-local.md)"; exit 1; }
command -v claude  >/dev/null 2>&1 || [[ "${1:-}" == "--server-only" ]] || { warn "claude not on PATH"; exit 1; }
if pgrep -f "ollama serve" >/dev/null 2>&1; then
    warn "Ollama is running; two residents do not fit in 24 GB. Stop it first."
    exit 1
fi

MARK="$(mktemp)"
trap 'rm -f "$MARK"' EXIT

FLAGS=(--model "$MODEL" --max-seq-length "$CTX" -np 1 --api-only --disable-tools -p "$PORT")
[[ -n "$VARIANT" ]] && FLAGS+=(--gguf-variant "$VARIANT")
# shellcheck disable=SC2206  # EXTRA is a deliberate space-separated flag list
[[ -n "$EXTRA" ]] && FLAGS+=($EXTRA)

say "Starting Unsloth: $MODEL${VARIANT:+ ($VARIANT)}, ctx $CTX, port $PORT"
(nohup unsloth run "${FLAGS[@]}" >/dev/null 2>&1 &)

KEY=""
T0=$(date +%s)
while [[ -z "$KEY" ]]; do
    if (( $(date +%s) - T0 > WAIT_S )); then
        warn "no API key after ${WAIT_S}s; newest log: $(ls -t "$LOG_DIR"/server-*.log 2>/dev/null | head -1)"
        exit 1
    fi
    LOG="$(find "$LOG_DIR" -name 'server-*.log' -newer "$MARK" 2>/dev/null | head -1 || true)"
    [[ -n "$LOG" ]] && KEY="$(grep -ho 'sk-unsloth-[A-Za-z0-9_-]*' "$LOG" 2>/dev/null | head -1 || true)"
    sleep 3
done
say "Server ready in $(( $(date +%s) - T0 ))s (key captured, not printed)"

if command -v hermes >/dev/null 2>&1; then
    hermes config set model.api_key "$KEY" >/dev/null 2>&1 && say "Hermes key updated (hermes --in <dir>)" \
        || warn "hermes present but 'hermes config set' failed"
fi

if [[ "${1:-}" == "--server-only" ]]; then
    say "Server only. Stop with: pkill -f 'unsloth run'"
    exit 0
fi

say "Launching Claude Code on the local model (MCP disabled)"
ANTHROPIC_BASE_URL="http://localhost:$PORT" ANTHROPIC_AUTH_TOKEN="$KEY" CLAUDE_CODE_ATTRIBUTION_HEADER=0 \
    claude --model "$MODEL" --strict-mcp-config --mcp-config <(echo '{"mcpServers":{}}') "$@"
say "Server still running. Stop with: pkill -f 'unsloth run'"
