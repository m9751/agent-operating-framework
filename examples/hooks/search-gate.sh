#!/usr/bin/env bash
# =============================================================================
# search-gate.sh — PreToolUse hook
#
# Blocks code generation and creation tools unless the agent has performed
# a search first. Enforces a "search before you build" discipline.
#
# How it works:
#   A companion hook (or the agent itself) logs each search operation to a
#   session-scoped breadcrumb file. This hook checks that file before
#   allowing creation tools to proceed.
#
# Breadcrumb contract:
#   The companion search-logger appends one line per search to:
#     $TMPDIR/agent-searches-${CLAUDE_SESSION_ID}.log
#   Each line is a free-text description of what was searched (e.g., the
#   query string or asset name). This hook checks whether at least one
#   search has been logged before allowing creation tools.
#
# Exit codes:
#   0 — allow (a search was logged, or tool is not a creation operation)
#   2 — block (creation attempted without a prior search)
#
# Hook type: PreToolUse
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Tools that create new code or resources.
# Customize this list for your environment.
CREATION_TOOLS=(
  "Write"
  "create_project"
  "generate_flow"
  "generate_spec"
  "deploy_function"
)

# Keywords in tool input that signal code creation via general-purpose tools.
# If the Bash or Edit tool contains these patterns, treat it as a creation event.
CREATION_PATTERNS=(
  "mkdir"
  "touch"
  "npm init"
  "npx create"
  "cargo init"
  "pip install.*&&.*cat.*>"
)

# Breadcrumb file — session-scoped via CLAUDE_SESSION_ID
BREADCRUMB_DIR="${TMPDIR:-/tmp}"
BREADCRUMB_FILE="${BREADCRUMB_DIR}/agent-searches-${CLAUDE_SESSION_ID:-unknown}.log"

# ---------------------------------------------------------------------------
# Read tool input from stdin (JSON)
# ---------------------------------------------------------------------------

INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
TOOL_INPUT="$(echo "$INPUT" | jq -r '.tool_input // empty')"

# ---------------------------------------------------------------------------
# Check: is this a creation tool?
# ---------------------------------------------------------------------------

is_creation_tool=false

# Direct match against known creation tools
for tool in "${CREATION_TOOLS[@]}"; do
  if [[ "$TOOL_NAME" == "$tool" ]]; then
    is_creation_tool=true
    break
  fi
done

# If not a direct match, check for creation patterns in Bash commands
if [[ "$is_creation_tool" == "false" && "$TOOL_NAME" == "Bash" ]]; then
  CMD="$(echo "$TOOL_INPUT" | jq -r '.command // empty')"
  for pattern in "${CREATION_PATTERNS[@]}"; do
    if echo "$CMD" | grep -qE "$pattern"; then
      is_creation_tool=true
      break
    fi
  done
fi

# If not a creation tool, allow unconditionally.
if [[ "$is_creation_tool" == "false" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Check the breadcrumb file for a prior search.
# ---------------------------------------------------------------------------

if [[ -f "$BREADCRUMB_FILE" ]] && [[ -s "$BREADCRUMB_FILE" ]]; then
  # At least one search has been logged — allow the creation.
  exit 0
fi

# No searches logged — block with a helpful message.
echo "BLOCKED: You are trying to create new code or resources, but no search has been logged this session."
echo ""
echo "Before creating anything from scratch, search for existing assets first:"
echo "  - Search your asset registry or package repository"
echo "  - Check if a template, library, or starter exists"
echo "  - Look for prior work in the codebase"
echo ""
echo "If an existing asset covers your use case, extend it instead of building from scratch."
echo "If nothing exists, log the search result (even a negative result) and try again."
echo ""
echo "To log a search breadcrumb, append to:"
echo "  ${BREADCRUMB_FILE}"
exit 2
