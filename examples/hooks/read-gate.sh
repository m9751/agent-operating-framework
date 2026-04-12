#!/usr/bin/env bash
# =============================================================================
# read-gate.sh — PreToolUse hook
#
# Blocks writes to infrastructure resources (database views, edge functions,
# config files) unless the agent has already read the target resource in
# this session.
#
# How it works:
#   A companion hook (or the agent itself) logs each "read" to a session-
#   scoped breadcrumb file. This hook checks that file before allowing any
#   write/mutate operation. If no prior read is found, the tool call is
#   blocked with exit 2 and a human-readable reason.
#
# Breadcrumb contract:
#   The companion read-logger appends one line per read to:
#     $TMPDIR/agent-reads-${CLAUDE_SESSION_ID}.log
#   Each line is the resource identifier that was read (e.g., a view name,
#   function name, or file path). This hook greps that file for a match.
#
# Exit codes:
#   0 — allow (resource was read, or tool is not a write operation)
#   2 — block (write attempted without a prior read)
#
# Hook type: PreToolUse
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Tools that perform write/mutate operations on infrastructure resources.
# Customize this list for your environment.
WRITE_TOOLS=(
  "Edit"
  "Write"
  "Bash"
  "execute_sql"
  "apply_migration"
  "deploy_edge_function"
)

# Breadcrumb file — session-scoped via CLAUDE_SESSION_ID
BREADCRUMB_DIR="${TMPDIR:-/tmp}"
BREADCRUMB_FILE="${BREADCRUMB_DIR}/agent-reads-${CLAUDE_SESSION_ID:-unknown}.log"

# ---------------------------------------------------------------------------
# Read tool input from stdin (JSON)
# ---------------------------------------------------------------------------

INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
TOOL_INPUT="$(echo "$INPUT" | jq -r '.tool_input // empty')"

# ---------------------------------------------------------------------------
# Check: is this a write tool we care about?
# ---------------------------------------------------------------------------

is_write_tool=false
for tool in "${WRITE_TOOLS[@]}"; do
  if [[ "$TOOL_NAME" == "$tool" ]]; then
    is_write_tool=true
    break
  fi
done

# If not a write tool, allow unconditionally.
if [[ "$is_write_tool" == "false" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Extract the target resource from the tool input.
#
# This section is intentionally simple — customize the extraction logic
# for your specific tools and resource naming conventions.
# ---------------------------------------------------------------------------

TARGET=""

case "$TOOL_NAME" in
  Edit|Write)
    # File path is the target resource
    TARGET="$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')"
    ;;
  execute_sql|apply_migration)
    # For SQL tools, look for known infrastructure keywords (views, functions)
    # and extract the resource name. This is a heuristic — adjust as needed.
    SQL_TEXT="$(echo "$TOOL_INPUT" | jq -r '.query // .sql // .statements // empty')"
    if echo "$SQL_TEXT" | grep -qiE '(CREATE|ALTER|DROP|REPLACE)\s+(VIEW|FUNCTION|TRIGGER|INDEX)'; then
      # Extract the resource name after the keyword
      TARGET="$(echo "$SQL_TEXT" | grep -oiE '(VIEW|FUNCTION|TRIGGER)\s+[a-zA-Z_][a-zA-Z0-9_.]*' | head -1)"
    fi
    ;;
  deploy_edge_function)
    TARGET="$(echo "$TOOL_INPUT" | jq -r '.name // .function_name // empty')"
    ;;
  Bash)
    # For bash commands that modify config files, extract the file path.
    # Only gate commands that look like they write to sensitive paths.
    CMD="$(echo "$TOOL_INPUT" | jq -r '.command // empty')"
    if echo "$CMD" | grep -qE '(settings\.json|settings\.xml|config\.(properties|yml|yaml|json))'; then
      # Extract the config file path
      TARGET="$(echo "$CMD" | grep -oE '[^ ]*settings\.(json|xml)[^ ]*|[^ ]*config\.(properties|yml|yaml|json)[^ ]*' | head -1)"
    fi
    ;;
esac

# If we couldn't identify a target resource, allow the operation.
# (Fail-open for unrecognized patterns — only gate what we understand.)
if [[ -z "$TARGET" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Check the breadcrumb file for a prior read of this resource.
# ---------------------------------------------------------------------------

if [[ ! -f "$BREADCRUMB_FILE" ]]; then
  # No reads logged at all this session — block.
  echo "BLOCKED: You are trying to modify \"$TARGET\" but have not read it yet this session."
  echo ""
  echo "Read the current state of the resource before modifying it."
  echo "This prevents acting on stale assumptions from a prior session."
  exit 2
fi

# Check if the target (or a recognizable substring) appears in the breadcrumb log.
if grep -qF "$TARGET" "$BREADCRUMB_FILE" 2>/dev/null; then
  # Prior read found — allow the write.
  exit 0
else
  echo "BLOCKED: You are trying to modify \"$TARGET\" but have not read it yet this session."
  echo ""
  echo "Read the current state of the resource first. Then this write will be allowed."
  echo ""
  echo "Resources read so far this session:"
  cat "$BREADCRUMB_FILE" 2>/dev/null || echo "  (none)"
  exit 2
fi
