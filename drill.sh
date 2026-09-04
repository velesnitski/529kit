#!/usr/bin/env bash
# 529kit drill — rehearse the outage while the cloud is still up.
# Measures the numbers you'll want during a real incident:
#   cold start (model load), warm reply, end-to-end agent run.
set -uo pipefail

MODEL="${KIT529_MODEL:-gpt-oss:20b}"
OLLAMA_API="http://localhost:11434"

echo "529kit drill — $(date '+%Y-%m-%d %H:%M')"
echo

# 0. doctor must pass first
if ! ./doctor.sh >/dev/null 2>&1; then
    echo "doctor.sh failed — fix health first, then drill."
    ./doctor.sh
    exit 1
fi
echo "[0] doctor: PASS"

gen() {  # one non-streaming generation, prints seconds
    local t0 t1
    t0=$(date +%s)
    curl -fsS --max-time 600 "$OLLAMA_API/api/generate" \
        -d "{\"model\":\"$MODEL\",\"prompt\":\"Reply with exactly one word: pong\",\"stream\":false}" >/dev/null
    t1=$(date +%s)
    echo $((t1 - t0))
}

# 1. cold start: unload first if loaded (ollama >= 0.5 supports `ollama stop`)
ollama stop "$MODEL" >/dev/null 2>&1 || true
sleep 2
echo "[1] cold start (model load + first reply)..."
COLD=$(gen) || { echo "    generation FAILED"; exit 1; }
echo "    ${COLD}s  ← expect this delay on the first question of a real incident"

# 2. warm reply
echo "[2] warm reply..."
WARM=$(gen) || { echo "    generation FAILED"; exit 1; }
echo "    ${WARM}s"

# 3. end-to-end through the agent harness, if present
if command -v hermes >/dev/null 2>&1; then
    echo "[3] end-to-end via hermes..."
    T0=$(date +%s)
    OUT=$(hermes -z "Reply with exactly one word: pong" 2>/dev/null | tail -1)
    T1=$(date +%s)
    if [[ "$OUT" == *pong* ]]; then
        echo "    $((T1-T0))s, answer: $OUT"
    else
        echo "    FAILED — hermes did not answer 'pong'. Check: hermes status (model/provider)."
        exit 1
    fi
else
    echo "[3] hermes not installed — skipped"
fi

# 4. cloud fallback tier (optional): set KIT529_CLOUD_MODEL to include it.
# Drill this tier too — free cloud tiers get overloaded, and reputation
# is not availability. A failure here is a warning, not a drill failure:
# the local tier above is the layer that must never depend on anyone.
if [[ -n "${KIT529_CLOUD_MODEL:-}" ]] && command -v hermes >/dev/null 2>&1; then
    echo "[4] cloud fallback tier ($KIT529_CLOUD_MODEL via ${KIT529_CLOUD_PROVIDER:-openrouter})..."
    T0=$(date +%s)
    OUT=$(hermes -z "Reply with exactly one word: pong" \
        -m "$KIT529_CLOUD_MODEL" --provider "${KIT529_CLOUD_PROVIDER:-openrouter}" 2>/dev/null | tail -1)
    T1=$(date +%s)
    if [[ "$OUT" == *pong* ]]; then
        echo "    $((T1-T0))s, answer: $OUT"
    else
        echo "    WARN: cloud tier did not answer (overloaded free tier?). Pick another model."
    fi
else
    echo "[4] cloud tier skipped (set KIT529_CLOUD_MODEL=<model> to drill it too)"
fi

echo
echo "DRILL PASSED. Numbers to remember: cold ${COLD}s, warm ${WARM}s."
echo "Keep-alive default unloads the model after ~5 min idle; during a long"
echo "incident export OLLAMA_KEEP_ALIVE=2h so you pay the cold start once."
echo
echo "Put the next drill in your calendar. A quarterly 5-minute drill is the"
echo "difference between a fallback and a hope."
