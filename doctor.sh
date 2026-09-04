#!/usr/bin/env bash
# 529kit doctor — 30-second health check. Exit 0 = ready for an outage.
set -uo pipefail

MODEL="${KIT529_MODEL:-gpt-oss:20b}"
OLLAMA_API="http://localhost:11434"
FAILS=0

row() { printf '  %-28s %s\n' "$1" "$2"; }
pass() { row "$1" "✓ $2"; }
fail() { row "$1" "✗ $2"; FAILS=$((FAILS+1)); }
note() { row "$1" "… $2"; }

echo "529kit doctor — $(date '+%Y-%m-%d %H:%M')"
echo

# ollama binary + server
if command -v ollama >/dev/null 2>&1; then pass "ollama binary" "$(ollama --version 2>/dev/null | head -1)"; else fail "ollama binary" "not found"; fi
if VER=$(curl -fsS --max-time 3 "$OLLAMA_API/api/version" 2>/dev/null); then pass "ollama server" "$VER"; else fail "ollama server" "no response on :11434"; fi

# model pulled
if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$MODEL"; then
    SIZE=$(ollama list | awk -v m="$MODEL" '$1==m {print $3" "$4}')
    pass "model $MODEL" "pulled ($SIZE)"
else
    fail "model $MODEL" "not pulled — run ./install.sh"
fi

# loaded right now?
if ollama ps 2>/dev/null | awk '{print $1}' | grep -qx "$MODEL"; then
    note "model in RAM" "loaded now (first reply will be fast)"
else
    note "model in RAM" "not loaded (first reply pays ~1 min load)"
fi

# RAM sanity
if [[ "$(uname)" == "Darwin" ]]; then
    RAM_GB=$(( $(sysctl -n hw.memsize) / 1073741824 ))
else
    RAM_GB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1048576 ))
fi
if [[ $RAM_GB -ge 24 ]]; then pass "RAM" "${RAM_GB} GB"; else note "RAM" "${RAM_GB} GB — prefer a smaller model (see README matrix)"; fi

# context length (matters for MCP tool schemas)
CTX="$( (command -v launchctl >/dev/null && launchctl getenv OLLAMA_CONTEXT_LENGTH) 2>/dev/null || printf '%s' "${OLLAMA_CONTEXT_LENGTH:-}")"
if [[ -n "$CTX" ]]; then
    pass "context length" "$CTX"
else
    note "context length" "unset → default 4096; fine for chat, TOO SMALL for MCP (see mcp/README.md)"
fi

# hermes
if command -v hermes >/dev/null 2>&1; then pass "hermes" "$(hermes --version 2>/dev/null | head -1)"; else fail "hermes" "not found — run ./install.sh"; fi

echo
if [[ $FAILS -eq 0 ]]; then
    echo "READY. Next: ./drill.sh (if you haven't drilled this quarter)."
else
    echo "NOT READY: $FAILS check(s) failed."
fi
exit "$FAILS"
