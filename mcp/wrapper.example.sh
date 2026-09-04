#!/bin/bash
# Example MCP wrapper for a fictional "acme-mcp" server.
# Copy to ~/.config/acme/wrapper.sh, chmod 700, adjust the three marked lines.
#
# Design:
#   - zero secrets inside this file (safe to keep anywhere)
#   - fail-closed: no env file -> refuses to start
#   - hardening env set here, not left to the model's good manners

set -a
source "$HOME/.config/acme/hermes.env" || exit 1   # (1) your env file, chmod 600
set +a

export ACME_READ_ONLY=1                            # (2) server-side write gate, if supported
export ACME_TOOL_TIER=core                         #     and/or a tool allowlist/tier

exec uvx acme-mcp                                  # (3) the real launch command
# or: exec uv run --directory "$HOME/src/acme-mcp" acme-mcp
