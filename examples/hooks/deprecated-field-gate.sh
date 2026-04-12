#!/usr/bin/env bash
# =============================================================================
# deprecated-field-gate.sh — PreToolUse hook
#
# Blocks tool calls that reference deprecated or obsolete field names,
# column names, or identifiers. Prevents the agent from using outdated
# schema references that would cause silent bugs or query failures.
#
# How it works:
#   Maintains a configurable map of deprecated terms and their replacements.
#   Scans the full tool input JSON for any deprecated term. If found, blocks
#   with exit 2 and names the correct replacement.
#
# Exit codes:
#   0 — allow (no deprecated terms found in tool input)
#   2 — block (deprecated term found; message names the replacement)
#
# Hook type: PreToolUse
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration: Deprecated terms and their replacements
#
# Format: "deprecated_term|replacement_term|description"
#
# Customize this list for your environment. Add entries whenever a schema
# migration renames a column, a config key changes, or an API field is
# superseded.
# ---------------------------------------------------------------------------

DEPRECATED_FIELDS=(
  # Example: database column renames
  "old_score_column|new_score_column|Renamed in migration 2024-01-15"
  "legacy_status|current_status|Renamed in migration 2024-02-20"
  "user_rating|user_score|Renamed in migration 2024-03-10"

  # Example: API field changes
  "api_key_v1|api_key_v2|V1 keys deprecated in API v3.0"
  "callback_url|webhook_url|Renamed in API v2.5"

  # Example: config key changes
  "old_config_key|new_config_key|Config restructured 2024-04-01"

  # Example: removed/replaced identifiers
  "deprecated_view_name|current_view_name|View recreated with new schema"

  # Add your own entries below:
  # "your_deprecated_column|your_replacement_column|Reason for deprecation"
)

# Tools to scan. Set to "*" to scan all tools, or list specific tool names.
# Scanning all tools is recommended — deprecated terms can appear anywhere.
SCAN_ALL_TOOLS=true
SCAN_TOOLS=(
  "execute_sql"
  "apply_migration"
  "Bash"
  "Edit"
  "Write"
  "Grep"
)

# ---------------------------------------------------------------------------
# Read tool input from stdin (JSON)
# ---------------------------------------------------------------------------

INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"

# ---------------------------------------------------------------------------
# Check: should we scan this tool?
# ---------------------------------------------------------------------------

if [[ "$SCAN_ALL_TOOLS" != "true" ]]; then
  should_scan=false
  for tool in "${SCAN_TOOLS[@]}"; do
    if [[ "$TOOL_NAME" == "$tool" ]]; then
      should_scan=true
      break
    fi
  done

  if [[ "$should_scan" == "false" ]]; then
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Flatten the entire tool input to a single string for scanning.
# This catches deprecated terms in any field — queries, file paths,
# command strings, code content, etc.
# ---------------------------------------------------------------------------

FLAT_INPUT="$(echo "$INPUT" | jq -r '.. | strings' 2>/dev/null | tr '\n' ' ')"

# ---------------------------------------------------------------------------
# Scan for deprecated terms
# ---------------------------------------------------------------------------

VIOLATIONS=""

for entry in "${DEPRECATED_FIELDS[@]}"; do
  IFS='|' read -r deprecated replacement reason <<< "$entry"

  # Use word-boundary matching to avoid false positives on substrings.
  # The \b works in GNU grep; adjust if using a different grep.
  if echo "$FLAT_INPUT" | grep -qiw "$deprecated" 2>/dev/null; then
    VIOLATIONS="${VIOLATIONS}\n  - \"${deprecated}\" is deprecated. Use \"${replacement}\" instead. (${reason})"
  fi
done

# ---------------------------------------------------------------------------
# If violations found, block with a clear message
# ---------------------------------------------------------------------------

if [[ -n "$VIOLATIONS" ]]; then
  echo "BLOCKED: Your tool call references deprecated field(s):"
  echo -e "$VIOLATIONS"
  echo ""
  echo "Update your query/code to use the current field names listed above,"
  echo "then try again."
  exit 2
fi

# No deprecated terms found — allow.
exit 0
