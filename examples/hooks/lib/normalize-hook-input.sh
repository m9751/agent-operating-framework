#!/usr/bin/env bash
# normalize-hook-input.sh — Shared hook payload normalization library
#
# SOURCE with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/normalize-hook-input.sh" 2>/dev/null || true
#
# Purpose: Claude Code hooks receive JSON payloads in Claude Code's snake_case
# shape. Other runtimes (Grok, future agents) emit camelCase shapes with
# different tool-name literals. This library normalizes the payload so every
# hook that sources it works regardless of which runtime fired it.
#
# What it normalizes:
#
#   Field names:
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
#     grep_search        → Bash       (grep is invoked via Bash in CC)
#     list_dir           → Bash
#
#   tool_input field aliases (Grok Write shape → Claude Code canonical), each with a
#   scan/execute-divergence CONFLICT guard (both-present-but-differ → fail closed):
#     tool_input.path     → tool_input.file_path
#     tool_input.contents → tool_input.content
#
# What it does NOT normalize:
#   - tool_input field structure (command, file_path, etc.) — those are
#     runtime-specific and each hook handles them already.
#   - MCP tool names — these are namespaced (mcp__*) and don't conflict.
#
# Usage:
#   1. Source this file near the top of your hook, after breadcrumb-lib.sh.
#   2. Read raw stdin into a variable.
#   3. Call nh_normalize "$RAW_INPUT" to get normalized JSON on stdout.
#   4. Use the normalized JSON with your existing Python parser.
#
# Example:
#   source "$SCRIPT_DIR/lib/normalize-hook-input.sh" 2>/dev/null || true
#   RAW=$(cat)
#   INPUT=$(nh_normalize "$RAW")
#   # ... your existing Python parser reads $INPUT ...
#
# Exit semantics of this library: none — it provides functions only.
# The calling hook owns all exit codes.
#
# Fail-open: if python3 is missing or the JSON parse fails, nh_normalize
# returns the original input unchanged. Hooks degrade to Claude Code-only
# behavior, which is the pre-normalization status quo — no regression.
#
# Design: smokin-os/spec/hooks-memory-skills-design.md §3.2 (Grok shape mismatch)
#         Track 1.1 done criterion: this file exists + top-offender hooks source it
#
# Bash hard rules (smokin-knowledge/bash/AGENTS.md):
#   Rule 1: set -euo pipefail — applied at the CALLING hook level; this library
#           intentionally does NOT call set -euo pipefail (sourced files that set
#           strict mode can change the calling hook's errexit behavior on source
#           errors — the || true on the source line is the caller's safety valve).
#   Rule 2: MSYS_NO_PATHCONV not needed (no native Win tools called)
#   Rule 3: No git pager calls
#   Rule 4: No state mutations — this library is read-only
#   Rule 5: No destructive commands
#
# Self-allowlist: hooks that source this file should add its basename to their
# own self-allowlist (if they have one) to prevent self-blocking.

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

  # Python normalization: rename camelCase fields, remap tool-name literals.
  local result
  result=$(printf '%s' "$raw" | python3 -c '
import json, sys

TOOL_NAME_MAP = {
    "run_terminal_cmd":     "Bash",
    "run_terminal_command": "Bash",
    "search_replace":       "Edit",
    "create_file":          "Write",
    "read_file":            "Read",
    "grep_search":          "Bash",
    "list_dir":             "Bash",
}

FIELD_MAP = {
    "toolName":   "tool_name",
    "toolInput":  "tool_input",
    "toolResult": "tool_result",
    "sessionId":  "session_id",
}

# CONFLICT sentinel (Codex Point A 2026-06-15, 2 HIGH bypass fixes). When a payload
# carries a field in BOTH shapes (e.g. camelCase toolInput AND snake_case tool_input, or
# tool_input.path AND tool_input.file_path with DIFFERENT values), normalization cannot
# pick a winner without risking scan/execute divergence: the gate could scan the clean
# branch while the runtime writes the secret branch. A security gate must NEVER let the
# scanned value differ from the executed value, so on conflict we emit a fixed sentinel and
# the calling SECURITY hook fails CLOSED. Non-security callers that ignore the sentinel get
# a non-JSON string and degrade safely (their JSON parse fails -> their own fail path).
CONFLICT = "__NH_CONFLICT__"

try:
    d = json.loads(sys.stdin.read())
except Exception:
    # Not valid JSON — emit empty to signal parse failure; caller fail-opens to raw.
    sys.exit(0)

if not isinstance(d, dict):
    # Top-level must be an object envelope; anything else is not a tool call we normalize.
    sys.exit(0)

# Finding 1 — dual envelope key collision. If any camelCase field AND its snake_case
# target are both present at the top level, last-write-wins would be attacker-controllable.
# Fail closed.
for cc_key, sc_key in FIELD_MAP.items():
    if cc_key in d and sc_key in d:
        print(CONFLICT, end="")
        sys.exit(0)

# Rename camelCase fields to snake_case (only top-level envelope fields).
normalized = {}
for k, v in d.items():
    mapped_key = FIELD_MAP.get(k, k)
    normalized[mapped_key] = v

# Remap tool-name literals.
if "tool_name" in normalized:
    normalized["tool_name"] = TOOL_NAME_MAP.get(normalized["tool_name"], normalized["tool_name"])

# Alias tool_input.path -> file_path (some Grok shapes use "path"). Three cases:
#   - only path present          -> alias path into file_path (the intended normalization)
#   - both present, SAME value   -> harmless, leave as-is
#   - both present, DIFFER       -> Finding 2: scan/execute divergence -> fail closed
# Non-dict tool_input is left untouched.
ti = normalized.get("tool_input")
if isinstance(ti, dict) and "path" in ti:
    if "file_path" not in ti:
        ti["file_path"] = ti["path"]
    elif ti["file_path"] != ti["path"]:
        print(CONFLICT, end="")
        sys.exit(0)

# Alias tool_input.contents -> content (some Grok Write shapes use "contents"). Same three cases
# as path/file_path above:
#   - only contents present       -> alias contents into content (the intended normalization)
#   - both present, SAME value    -> harmless, leave as-is
#   - both present, DIFFER        -> scan/execute divergence -> fail closed (CONFLICT sentinel)
# Non-dict tool_input is left untouched (ti is re-checked because the path branch may have run).
if isinstance(ti, dict) and "contents" in ti:
    if "content" not in ti:
        ti["content"] = ti["contents"]
    elif ti["content"] != ti["contents"]:
        print(CONFLICT, end="")
        sys.exit(0)

print(json.dumps(normalized), end="")
' 2>/dev/null) || result=""

  if [ -z "$result" ]; then
    # Normalization failed — return original input unchanged (fail-open).
    printf '%s' "$raw"
  else
    printf '%s' "$result"
  fi
}

# nh_tool_name <json_string>
#
# Convenience: extract the normalized tool_name without a full normalize pass.
# Useful for quick dispatch checks (e.g., "is this a Bash call?").
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
