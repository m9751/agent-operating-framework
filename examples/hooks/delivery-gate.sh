#!/usr/bin/env bash
# =============================================================================
# delivery-gate.sh — PreToolUse hook (advisory, fail-open)
#
# Tracks whether the agent has logged a deliverable to the tracking system.
# When it detects an INSERT-like operation to a deliverables table, it writes
# a breadcrumb. When the agent tries to start a new task (signaled by certain
# tool patterns), it checks whether the previous deliverable was logged.
#
# This is a SOFT REMINDER, not a hard block. It always exits 0.
# The goal is to build a habit, not to prevent work.
#
# Breadcrumb contract:
#   This hook writes to:
#     $TMPDIR/agent-deliveries-${CLAUDE_SESSION_ID}.log
#   Each line is a timestamp + description of the logged deliverable.
#
# Exit codes:
#   0 — always (this is an advisory hook, never blocks)
#
# Hook type: PreToolUse
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Table names that represent your deliverable tracking system.
# Customize these for your environment.
TRACKING_TABLES=(
  "deliverables"
  "delivery_log"
  "project_artifacts"
  "task_log"
)

# Tools that signal "starting new work" — when these fire, check if the
# previous deliverable was logged.
NEW_WORK_SIGNALS=(
  "create_project"
  "generate_spec"
  "generate_flow"
)

# Breadcrumb file — session-scoped via CLAUDE_SESSION_ID
BREADCRUMB_DIR="${TMPDIR:-/tmp}"
BREADCRUMB_FILE="${BREADCRUMB_DIR}/agent-deliveries-${CLAUDE_SESSION_ID:-unknown}.log"

# Counter file — tracks how many deliverables were built vs. logged
COUNTER_FILE="${BREADCRUMB_DIR}/agent-delivery-count-${CLAUDE_SESSION_ID:-unknown}.txt"

# ---------------------------------------------------------------------------
# Read tool input from stdin (JSON)
# ---------------------------------------------------------------------------

INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
TOOL_INPUT="$(echo "$INPUT" | jq -r '.tool_input // empty')"

# ---------------------------------------------------------------------------
# Detect INSERT to a tracking table — log a breadcrumb
# ---------------------------------------------------------------------------

detect_delivery_log() {
  local text="$1"

  for table in "${TRACKING_TABLES[@]}"; do
    if echo "$text" | grep -qiE "INSERT\s+INTO\s+[\"']?${table}[\"']?"; then
      local timestamp
      timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo "${timestamp} Logged to ${table}" >> "$BREADCRUMB_FILE"
      return 0
    fi
  done
  return 1
}

# Check SQL-bearing tools for INSERT patterns
case "$TOOL_NAME" in
  execute_sql|apply_migration|Bash)
    SQL_OR_CMD="$(echo "$TOOL_INPUT" | jq -r '.query // .sql // .command // empty')"
    if [[ -n "$SQL_OR_CMD" ]]; then
      detect_delivery_log "$SQL_OR_CMD" || true
    fi
    ;;
esac

# ---------------------------------------------------------------------------
# When starting new work, remind if previous deliverable wasn't logged
# ---------------------------------------------------------------------------

is_new_work=false

# Direct match against new-work signal tools
for tool in "${NEW_WORK_SIGNALS[@]}"; do
  if [[ "$TOOL_NAME" == "$tool" ]]; then
    is_new_work=true
    break
  fi
done

# Also detect new HTML builds or file creation as new work signals
if [[ "$TOOL_NAME" == "Write" ]]; then
  FILE_PATH="$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')"
  if echo "$FILE_PATH" | grep -qE '\.(html|tsx|jsx|py|js)$'; then
    is_new_work=true
  fi
fi

if [[ "$is_new_work" == "true" ]]; then
  # Count deliverables completed (Write calls to output files) vs. logged
  LOGGED_COUNT=0
  if [[ -f "$BREADCRUMB_FILE" ]]; then
    LOGGED_COUNT="$(wc -l < "$BREADCRUMB_FILE" | tr -d ' ')"
  fi

  if [[ "$LOGGED_COUNT" -eq 0 ]]; then
    # Advisory reminder — printed to stderr so it appears in hook output
    echo "REMINDER: No deliverables have been logged to the tracking system this session." >&2
    echo "After completing a deliverable, log it (INSERT to your tracking table)." >&2
    echo "This is a reminder, not a block. Continuing..." >&2
  fi
fi

# ---------------------------------------------------------------------------
# Always exit 0 — this hook is advisory only
# ---------------------------------------------------------------------------
exit 0
