#!/usr/bin/env bash
# fail-mode: open
# blast-radius: advisory
# =============================================================================
# focus-breadcrumb.sh — UserPromptSubmit hook
#
# Companion to focus-confirmation-gate.sh. Detects when the operator's prompt
# is an "explicit task" (named target + actionable verb) and writes a
# session-scoped breadcrumb. The gate hook reads this breadcrumb to decide
# whether the upcoming tool call should pass silently or surface a warning.
#
# Why a pair (writer + gate) instead of one hook:
#   UserPromptSubmit fires once per operator message.
#   PreToolUse fires once per tool call.
#   Two different hook events; two different scripts; one shared breadcrumb.
#
# Explicit-task pattern:
#   Any of the verbs in EXPLICIT_VERBS, followed by optional "the", followed
#   by at least one non-whitespace token. Matches "fix the build", "deploy
#   auth", "ship v1.5", "merge it". Misses pure questions and open
#   invitations ("what should we work on?", "can you look at the codebase?").
#
# Breadcrumb shape:
#   <ISO timestamp>\t<matched verb>\t<short context>
#   One line per qualifying prompt. Persists for the session.
#
# Hook type: UserPromptSubmit
# Exit codes:
#   0 — always (advisory; never blocks)
#
# Usage (CI self-test):
#   echo '{"prompt":"fix the build"}' | bash examples/hooks/focus-breadcrumb.sh
# =============================================================================

set -euo pipefail

EXPLICIT_VERBS='fix|deploy|build|write|refactor|create|add|update|remove|delete|merge|run|check|review|push|implement|investigate|debug|ship|tag|release|commit|audit|wire|bundle'

BREADCRUMB_DIR="${TMPDIR:-/tmp}"
BREADCRUMB_FILE="${BREADCRUMB_DIR}/agent-focus-${CLAUDE_SESSION_ID:-default}.log"

# ---------------------------------------------------------------------------
# Read prompt from stdin.
# ---------------------------------------------------------------------------

INPUT="$(cat)"

if command -v jq >/dev/null 2>&1; then
  PROMPT="$(echo "$INPUT" | jq -r '.prompt // empty')"
else
  # Fallback: treat raw stdin as the prompt.
  PROMPT="$INPUT"
fi

if [[ -z "$PROMPT" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Match explicit-task pattern.
# ---------------------------------------------------------------------------

# Case-insensitive: \b<verb>\b followed by optional "the" and at least one
# non-whitespace token. The trailing token guards against bare verbs like
# "fix" by themselves.
MATCH_REGEX="\\b(${EXPLICIT_VERBS})\\b[[:space:]]+(the[[:space:]]+)?[^[:space:]]+"

if matched_verb="$(echo "$PROMPT" | grep -ioE "\\b(${EXPLICIT_VERBS})\\b" | head -1)"; then
  if [[ -n "$matched_verb" ]] && echo "$PROMPT" | grep -qiE "$MATCH_REGEX"; then
    # Capture a short context window (first 80 chars of the prompt, single line).
    short_ctx="$(echo "$PROMPT" | tr '\n' ' ' | cut -c 1-80)"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
    printf '%s\t%s\t%s\n' "$ts" "$matched_verb" "$short_ctx" >> "$BREADCRUMB_FILE"
  fi
fi

# Always exit 0 (advisory; never blocks).
exit 0
