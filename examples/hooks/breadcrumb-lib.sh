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
#   source "$(dirname "${BASH_SOURCE[0]}")/breadcrumb-lib.sh" 2>/dev/null || true
#
# The || true means hooks still run if this library is missing (fail-open).
#
# SCHEMA ASSUMPTION: bc_session_key() depends on CLAUDE_CODE_SESSION_ID,
# set by the Claude Code runtime on every platform (Mac and Win11 both
# confirmed). Falls back to USER-$$ for CI or manual shell runs where
# Claude Code is not the host.
#
# Cross-subprocess stability: bc_session_key() must return the SAME value
# from two separate bash subprocesses in the same Claude Code session.
# The CLAUDE_CODE_SESSION_ID env var satisfies this; $$ does NOT (each
# subprocess gets a different PID). Verified by regression smoke at
# tests/smoke/hooks/breadcrumb-lib/smoke.sh.
#
# Storage model: one file per named breadcrumb.
#   Path: $(bc_dir)/<session_key>-<name>
#   Content: arbitrary string value (default "1")
#   Absence of a file = breadcrumb not set for this session.
#
# Functions:
#   bc_session_key  — returns the session identifier string
#   bc_dir          — returns the directory where breadcrumbs are written
#   bc_write        — writes a named breadcrumb file
#   bc_exists       — returns 0 if the named breadcrumb file exists and is non-empty
#   bc_read         — prints the content of a named breadcrumb file
#
# Hook type: library (source, do not execute directly)
# =============================================================================

# Do NOT set -euo pipefail here — this is a library sourced into hooks that
# may have their own error-handling settings. Let the caller control errexit.

# ---------------------------------------------------------------------------
# bc_session_key
#
# Returns the canonical session identifier.
# ---------------------------------------------------------------------------
bc_session_key() {
  echo "${CLAUDE_CODE_SESSION_ID:-${USER:-unknown}-$$}"
}

# ---------------------------------------------------------------------------
# bc_dir
#
# Returns the directory for breadcrumb files.
# Defaults to /tmp/claude-hooks-<user>.
# Override by setting BREADCRUMB_DIR before sourcing this library.
# ---------------------------------------------------------------------------
bc_dir() {
  echo "${BREADCRUMB_DIR:-/tmp/claude-hooks-${USER:-unknown}}"
}

# ---------------------------------------------------------------------------
# bc_write <name> [value]
#
# Writes a named breadcrumb file for the current session.
# File path: $(bc_dir)/<session_key>-<name>
# Content: <value> (defaults to "1")
#
# The directory is created if it does not exist.
#
# Example:
#   bc_write "exchange-search-done"
#   bc_write "target-resource" "auth/login.ts"
# ---------------------------------------------------------------------------
bc_write() {
  local name="$1"
  local value="${2:-1}"
  local dir; dir=$(bc_dir)
  mkdir -p "$dir"
  echo "$value" > "$dir/$(bc_session_key)-${name}"
}

# ---------------------------------------------------------------------------
# bc_exists <name>
#
# Returns exit 0 if the named breadcrumb file exists and is non-empty.
# Returns exit 1 otherwise.
#
# Example:
#   if bc_exists "exchange-search-done"; then echo "already searched"; fi
# ---------------------------------------------------------------------------
bc_exists() {
  local name="$1"
  local dir; dir=$(bc_dir)
  [ -s "$dir/$(bc_session_key)-${name}" ]
}

# ---------------------------------------------------------------------------
# bc_read <name>
#
# Prints the content of the named breadcrumb file.
# Prints nothing (exit 0) if the file does not exist.
#
# Example:
#   resource=$(bc_read "target-resource")
# ---------------------------------------------------------------------------
bc_read() {
  local name="$1"
  local dir; dir=$(bc_dir)
  cat "$dir/$(bc_session_key)-${name}" 2>/dev/null
}
