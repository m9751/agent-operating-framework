#!/usr/bin/env bash
# fail-mode: open
# blast-radius: advisory
# =============================================================================
# normalize-hook-input.sh — Cross-runtime hook payload normalization library
#
# SOURCE with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/normalize-hook-input.sh" 2>/dev/null || true
#
# Problem: Claude Code hooks receive JSON payloads in snake_case with
# "Bash"/"Edit"/"Write" tool-name literals. Other runtimes (Grok and future
# agents) emit camelCase payloads with different tool-name literals:
#
#   Claude Code:  {"tool_name": "Bash",   "tool_input": {...}}
#   Grok:         {"toolName":  "run_terminal_cmd", "toolInput": {...}}
#
# Without normalization, a hook that checks `tool_name == "Bash"` silently
# bypasses on Grok — the check never fires, the gate never blocks.
#
# What this library normalizes:
#
#   Field names (camelCase → snake_case):
#     toolName    → tool_name
#     toolInput   → tool_input
#     toolResult  → tool_result
#     sessionId   → session_id
#
#   Tool-name literals (Grok → Claude Code canonical):
#     run_terminal_cmd   → Bash
#     search_replace     → Edit
#     create_file        → Write
#     read_file          → Read
#     grep_search        → Bash
#     list_dir           → Bash
#
# What this library does NOT normalize:
#   - tool_input field structure (command, file_path, etc.) — hooks handle these
#   - MCP tool names (mcp__*) — namespaced, no conflicts
#
# Usage:
#   1. Source this file near the top of your hook, after breadcrumb-lib.sh.
#   2. Read raw stdin into a variable (do not consume stdin twice).
#   3. Call nh_normalize "$RAW_INPUT" to get normalized JSON on stdout.
#   4. Pass the normalized JSON to your existing parser.
#
# Example:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/normalize-hook-input.sh" 2>/dev/null || true
#   RAW=$(cat)
#   INPUT=$(nh_normalize "$RAW")
#   TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))")
#
# Fail-open guarantee: if python3 is missing or JSON parse fails, nh_normalize
# returns the original input unchanged. Every hook that sources this library
# degrades to Claude Code-only behavior — the pre-normalization status quo.
# No regression.
#
# Library exit semantics: none — this file provides functions only.
# The calling hook owns all exit codes.
#
# Hook type: library (source, do not execute directly)
# =============================================================================

# Do NOT set -euo pipefail in a sourced library — it affects the calling hook's
# errexit behavior. Let the caller control error handling.

# nh_normalize <json_string>
#
# Emits a normalized JSON string on stdout.
# On any failure, emits the original input unchanged (fail-open).
nh_normalize() {
  local raw="${1:-}"
  if [ -z "$raw" ]; then
    printf '%s' "$raw"
    return
  fi

  local result
  result=$(printf '%s' "$raw" | python3 -c '
import json, sys

TOOL_NAME_MAP = {
    "run_terminal_cmd": "Bash",
    "search_replace":   "Edit",
    "create_file":      "Write",
    "read_file":        "Read",
    "grep_search":      "Bash",
    "list_dir":         "Bash",
}

FIELD_MAP = {
    "toolName":   "tool_name",
    "toolInput":  "tool_input",
    "toolResult": "tool_result",
    "sessionId":  "session_id",
}

try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)  # fail-open: caller receives empty, returns original

normalized = {}
for k, v in d.items():
    normalized[FIELD_MAP.get(k, k)] = v

if "tool_name" in normalized:
    normalized["tool_name"] = TOOL_NAME_MAP.get(normalized["tool_name"], normalized["tool_name"])

print(json.dumps(normalized), end="")
' 2>/dev/null) || result=""

  if [ -z "$result" ]; then
    printf '%s' "$raw"
  else
    printf '%s' "$result"
  fi
}

# nh_tool_name <json_string>
#
# Convenience: extract the normalized tool_name without a full normalize pass.
# Useful for quick dispatch checks in PreToolUse hooks.
#
# Example:
#   tool=$(nh_tool_name "$RAW")
#   [[ "$tool" == "Bash" ]] && echo "bash call"
nh_tool_name() {
  local raw="${1:-}"
  [ -z "$raw" ] && { printf ''; return; }
  printf '%s' "$raw" | python3 -c '
import json, sys
TOOL_NAME_MAP = {
    "run_terminal_cmd": "Bash",
    "search_replace":   "Edit",
    "create_file":      "Write",
    "read_file":        "Read",
    "grep_search":      "Bash",
    "list_dir":         "Bash",
}
try:
    d = json.load(sys.stdin)
    raw_name = d.get("tool_name") or d.get("toolName", "")
    print(TOOL_NAME_MAP.get(raw_name, raw_name), end="")
except Exception:
    print("", end="")
' 2>/dev/null || printf ''
}
