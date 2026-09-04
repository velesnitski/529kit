# Wiring your MCP servers into the local agent

Your MCP servers (monitoring, GitLab, tickets, DB…) can keep working during a
cloud outage — the model driving them changes, the tools don't. This recipe
was field-tested end-to-end with a production read-only monitoring MCP.

## The six steps

1. **Find the server's launch config** in your cloud assistant's config
   (command / args / env). Don't reinvent it — reuse it.

2. **Secrets go to a dedicated env file, created by hand:**
   `~/.config/<name>/hermes.env`, `chmod 600`, lines of `KEY='value'`.
   Never into the harness config, never into a repo, never through a
   script that parses your assistant's credential files (if you have a
   security hook that blocks that — good, it's right).

3. **Write a wrapper** (see `wrapper.example.sh`): sources the env file
   (**fail-closed** — exits if the file is missing), adds hardening env,
   then `exec`s the real server. The wrapper itself contains zero secrets,
   so it can live anywhere.

4. **Respect the size rule: ≤ 30 tools on a 16k context.** A 150-tool
   server's schemas alone blow past a small model's window — and the
   Ollama *default* is 4096, which is too small even for 30. Fix both:
   - server-side, if your MCP supports it (a tier/allowlist env var) —
     preferred;
   - harness-side: answer `select` instead of `Y` when adding;
   - raise the context: `launchctl setenv OLLAMA_CONTEXT_LENGTH 16384`
     and restart the Ollama app (macOS; re-run after every reboot).

5. **Register and smoke-test:**
   ```bash
   printf 'Y\n' | hermes mcp add <name> --command ~/.config/<name>/wrapper.sh
   hermes mcp test <name>
   hermes -z "call <one read tool>. one line."
   ```

6. **Write down the operational tail** in your runbook: the secret file is
   a *second place* to update on token rotation; intranet servers need the
   VPN up (DNS-flap signature: `nodename nor servname provided, or not
   known` — check the VPN before debugging the harness).

## Security rules (non-negotiable)

- **Read-only gates live server-side.** If your MCP has a read-only env
  flag — set it in the wrapper. A small local model *will* eventually
  hallucinate a destructive call; the server must refuse it, not the
  model's good manners. If your server has no such flag, add one before
  wiring it to a 20B.
- **Fail closed everywhere.** Missing env file → wrapper exits → harness
  refuses to save a dead server. Verify this on purpose during setup.
- Expect ~40–60 s per tool round-trip warm on a 20B — write prompts that
  need 2–3 calls, not ten.

## What a small model can do with your tools

Verified: with a **scaffolded prompt** (exact tool names, exact argument
names, explicit output format — see `../prompts/`), a 20B reliably runs
fixed 2–3-call scenarios and reports facts accurately. Without scaffolding
it invents argument names and dies on the first validation error. Plan
fixed playbooks, not free-form investigation.
