#!/usr/bin/env bash
# fail-mode: open
# blast-radius: advisory
# =============================================================================
# breadcrumb-lib.sh — Shared breadcrumb library for AOF hooks
#
# Provides five functions for session-scoped breadcrumb read/write.
# Source this file at the top of any hook that needs to log or check
# session state:
#
#   source "$(dirname "$0")/breadcrumb-lib.sh"
#
# SCHEMA ASSUMPTION: bc_session_key() depends on the following env vars,
# checked in priority order:
#   (a) CLAUDE_CODE_SESSION_ID — canonical; set by the Claude Code runtime on
#       both Mac and Win11. This is the authoritative session identifier.
#   (b) CLAUDE_SESSION_ID — legacy backstop. Set via shell init on some Mac
#       configurations. Empty on Win11. Kept for backwards compatibility until
#       a Mac platform probe confirms it is redundant.
#   (c) "default" — last-resort fallback. When the key is "default", all
#       breadcrumb operations still succeed but session isolation is lost
#       (multiple sessions share one file). Log a warning to stderr in this
#       case if the calling hook cares about isolation.
#
# Cross-subprocess stability: bc_session_key() must return the SAME value
# from two separate bash -c subprocesses in the same Claude Code session.
# Verified via the regression smoke at tests/smoke/hooks/breadcrumb-lib/smoke.sh.
#
# How to retire the CLAUDE_SESSION_ID backstop:
#   Run `printenv | grep -i CLAUDE` inside a Claude Code session on Mac and
#   confirm CLAUDE_CODE_SESSION_ID is present and non-empty. Once confirmed
#   across both Mac and Win11, remove the (b) branch and this note.
#
# Functions:
#   bc_session_key  — returns the session identifier string
#   bc_dir          — returns the directory where breadcrumbs are written
#   bc_write        — appends a breadcrumb line to the session file
#   bc_exists       — returns 0 if one or more breadcrumbs match a pattern
#   bc_read         — prints all breadcrumb lines matching a pattern
#
# Hook type: library (source, do not execute directly)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# bc_session_key
#
# Returns the canonical session identifier. See SCHEMA ASSUMPTION above.
# ---------------------------------------------------------------------------
bc_session_key() {
  if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
    echo "${CLAUDE_CODE_SESSION_ID}"
  elif [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
    echo "${CLAUDE_SESSION_ID}"
  else
    echo "default"
  fi
}

# ---------------------------------------------------------------------------
# bc_dir
#
# Returns the directory for breadcrumb files. Defaults to $TMPDIR or /tmp.
# Override by setting BREADCRUMB_DIR before sourcing this library.
# ---------------------------------------------------------------------------
bc_dir() {
  echo "${BREADCRUMB_DIR:-${TMPDIR:-/tmp}}"
}

# ---------------------------------------------------------------------------
# bc_write <namespace> <payload>
#
# Appends one breadcrumb line to the session file for <namespace>.
# File path: <bc_dir>/agent-<namespace>-<session_key>.log
# Line format: <ISO timestamp>	<payload>
#
# Example:
#   bc_write "reads" "auth/login.ts"
#   bc_write "focus" "fix	fix the build"
# ---------------------------------------------------------------------------
bc_write() {
  local namespace="$1"
  local payload="$2"
  local key; key="$(bc_session_key)"
  local file; file="$(bc_dir)/agent-${namespace}-${key}.log"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
  printf '%s	%s
' "$ts" "$payload" >> "$file"
}

# ---------------------------------------------------------------------------
# bc_exists <namespace> <pattern>
#
# Returns exit 0 if any line in the session file for <namespace> contains
# <pattern> (fixed-string match). Returns exit 1 otherwise.
#
# Example:
#   if bc_exists "reads" "auth/login.ts"; then echo "already read"; fi
# ---------------------------------------------------------------------------
bc_exists() {
  local namespace="$1"
  local pattern="$2"
  local key; key="$(bc_session_key)"
  local file; file="$(bc_dir)/agent-${namespace}-${key}.log"
  [[ -f "$file" ]] && grep -qF "$pattern" "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# bc_read <namespace> [pattern]
#
# Prints all lines from the session file for <namespace>. If <pattern> is
# provided, filters to lines containing it (fixed-string match).
#
# Example:
#   bc_read "reads"          # all reads this session
#   bc_read "reads" "auth"   # reads matching "auth"
# ---------------------------------------------------------------------------
bc_read() {
  local namespace="$1"
  local pattern="${2:-}"
  local key; key="$(bc_session_key)"
  local file; file="$(bc_dir)/agent-${namespace}-${key}.log"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  if [[ -n "$pattern" ]]; then
    grep -F "$pattern" "$file" 2>/dev/null || true
  else
    cat "$file"
  fi
}
