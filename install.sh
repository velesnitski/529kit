#!/usr/bin/env bash
# 529kit installer — idempotent: every step is skipped if already satisfied.
set -euo pipefail

MODEL="${KIT529_MODEL:-gpt-oss:20b}"
OLLAMA_API="http://localhost:11434"

say()  { printf '\033[1;36m[529kit]\033[0m %s\n' "$*"; }
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$*"; }

# --- 1. Ollama binary -------------------------------------------------------
say "Checking Ollama..."
if command -v ollama >/dev/null 2>&1; then
    ok "ollama present: $(ollama --version 2>/dev/null | head -1)"
else
    if [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        say "Installing Ollama via Homebrew..."
        brew install --cask ollama
    else
        warn "Install Ollama manually: https://ollama.com/download — then re-run."
        exit 1
    fi
fi

# --- 2. Ollama server -------------------------------------------------------
say "Checking Ollama server..."
if curl -fsS --max-time 3 "$OLLAMA_API/api/version" >/dev/null 2>&1; then
    ok "server responding on :11434"
else
    if [[ "$(uname)" == "Darwin" ]]; then
        say "Starting Ollama app..."
        open -a Ollama 2>/dev/null || (nohup ollama serve >/dev/null 2>&1 &)
    else
        say "Starting ollama serve in background..."
        (nohup ollama serve >/dev/null 2>&1 &)
    fi
    sleep 5
    curl -fsS --max-time 5 "$OLLAMA_API/api/version" >/dev/null || {
        warn "Server still not up. Start it manually (ollama serve) and re-run."
        exit 1
    }
    ok "server started"
fi

# --- 3. Model ---------------------------------------------------------------
say "Checking model $MODEL (override with KIT529_MODEL=...)..."
if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$MODEL"; then
    ok "model already pulled"
else
    say "Pulling $MODEL — this is a multi-GB download, one time only..."
    ollama pull "$MODEL"
    ok "model pulled"
fi

# --- 4. Hermes agent harness ------------------------------------------------
say "Checking Hermes..."
if command -v hermes >/dev/null 2>&1; then
    ok "hermes present: $(hermes --version 2>/dev/null | head -1)"
else
    say "Installing Hermes (official installer)..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
    command -v hermes >/dev/null 2>&1 || warn "hermes not on PATH yet — open a new shell, then run: hermes setup"
fi

say "Done. Next steps:"
echo "  1) If Hermes is fresh: run 'hermes setup' and point it at custom endpoint $OLLAMA_API/v1 with model $MODEL"
echo "  2) ./doctor.sh   — verify everything"
echo "  3) ./drill.sh    — rehearse the outage while the cloud is still up"
