#!/usr/bin/env bash
# fail-mode: open
# blast-radius: advisory
# =============================================================================
# focus-confirmation-gate.sh — PreToolUse hook
#
# Companion to focus-breadcrumb.sh. Fires before Edit/Write/Bash tool calls
# and checks the session-scoped focus breadcrumb. If no breadcrumb exists,
# emits a stderr warning recommending the agent ask the operator to confirm
# focus before destructive actions. Always exits 0 (advisory).
#
# Why advisory and not fail-closed:
#   §1.3 of AGENT_FRAMEWORK.md establishes precedence over §0.5 Step 3 —
#   explicit bug reports / named-target+actionable-verb requests ARE focus
#   confirmation. Hard-blocking the first action would create the friction
#   §1.3 explicitly rejects. The warning surfaces the case where intent
#   was ambiguous AND the agent jumped ahead.
#
# Gated tools:
#   Edit, Write, Bash. Read/Grep/Glob are allowed pre-confirmation
#   (research is part of orientation, not destructive action).
#
# Hook type: PreToolUse
# Exit codes:
#   0 — always (advisory; never blocks)
#
# Usage (CI self-test):
#   echo '{"tool_name":"Write","tool_input":{...}}' | bash examples/hooks/focus-confirmation-gate.sh
# =============================================================================

set -euo pipefail

GATED_TOOLS=("Edit" "Write" "Bash")

BREADCRUMB_DIR="${TMPDIR:-/tmp}"
BREADCRUMB_FILE="${BREADCRUMB_DIR}/agent-focus-${CLAUDE_SESSION_ID:-default}.log"

# ---------------------------------------------------------------------------
# Read tool input.
# ---------------------------------------------------------------------------

INPUT="$(cat)"

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
else
  TOOL_NAME=""
fi

# ---------------------------------------------------------------------------
# Only run for gated tools.
# ---------------------------------------------------------------------------

is_gated=false
for tool in "${GATED_TOOLS[@]}"; do
  if [[ "$TOOL_NAME" == "$tool" ]]; then
    is_gated=true
    break
  fi
done

if [[ "$is_gated" == "false" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Check breadcrumb.
# ---------------------------------------------------------------------------

if [[ ! -s "$BREADCRUMB_FILE" ]]; then
  echo "::warning::focus-confirmation-gate: no focus breadcrumb found this session." >&2
  echo "Per session-lifecycle.md Phase 1, the agent should ask the operator to confirm focus before destructive actions." >&2
  echo "Per §1.3 precedence, an explicit named-target + actionable-verb request would have written the breadcrumb automatically (see focus-breadcrumb.sh)." >&2
fi

# Always exit 0 (advisory; never blocks).
exit 0
