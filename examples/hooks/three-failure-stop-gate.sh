#!/bin/bash
# THREE-FAILURE-STOP GATE — PreToolUse hook for Bash
# Targets: AOF v1.6 — DP2 + DP3 (Three-Failure-Stop discipline).
# Source: AOF AGENT_FRAMEWORK.md §4 (Three-Failure-Stop).
# Postmortem: 2026-05-15 kb_mcp_server saga (8 fix(...) commits in 2hr).
#
# How it works:
#   1. PreToolUse fires on every Bash call.
#   2. If the command is `git commit` with message matching ^fix\(...\):
#      append timestamp to ~/.claude/state/three-failure-stop/<repo>__<file>.log
#      then count entries in the last 2hr.
#   3. If count >= 4 AND commit body does NOT contain
#      "# halted-and-researched: <something>", block with stderr explaining how
#      to override.
#
# State files are append-only timestamps, one per line. Counter uses awk to
# filter ts > now - 7200. Append happens only AFTER the gate decides to allow
# (F4 fix Codex 2026-05-15) — blocked invocations no longer inflate the counter.
#
# KNOWN GAPS (v1.6 — addressed in v1.7):
#   F3: The fix-trigger regex `fix\([^)]*\):` matches anywhere in the command
#       string, including directory names. `cd /repo/fix(mcp)/bar && commit`
#       could trip the counter on a non-fix commit. Contrived in practice;
#       restage if false-positive observed.
#   F6: `git commit -F msg.txt`, `git commit --file=msg.txt`, `git commit -F -`,
#       and `EDITOR=true git commit` bypass this gate. Counter relies on inline
#       -m text; file/editor-based message paths are invisible. v1.7 PostToolUse
#       companion will re-check via `git log -1 --format=%B`.
#   F9: `git --git-dir=X --work-tree=Y commit` form is not parsed by the repo
#       resolver. Falls through to Priority 3/4 cwd, then fail-open with
#       advisory warn (this gate is advisory by design — false-positives more
#       disruptive than false-negatives).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/breadcrumb-lib.sh" 2>/dev/null || true
trap 'bc_record_exit "three-failure-stop-gate" "$?"' EXIT

STATE_ROOT="${HOME}/.claude/state/three-failure-stop"
WINDOW_SECONDS=7200    # 2 hours
THRESHOLD=4            # 4th fix(...) in window triggers the block

INPUT=$(cat)

# Normalize camelCase (Grok) → snake_case (Claude Code) so Grok-shaped git commit
# payloads (toolInput instead of tool_input) are not silently bypassed.
source "$SCRIPT_DIR/lib/normalize-hook-input.sh" 2>/dev/null || true
if command -v nh_normalize >/dev/null 2>&1; then
  _NORM="$(nh_normalize "$INPUT")"
  # __NH_CONFLICT__: dual-shape payload — fail open (advisory gate; false-positives
  # more disruptive than false-negatives, consistent with gate's existing posture).
  [ "$_NORM" != "__NH_CONFLICT__" ] && INPUT="$_NORM"
  unset _NORM
fi

# Extract tool_input.command via Python — grep+sed truncates at escaped quotes
# inside commit messages. Python is the cleanest dep-free fix on Win11.
COMMAND=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""), end="")
except Exception:
    pass
' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  printf '%s\tthree-failure-stop-gate\tcommand-parse-empty\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 0
fi

if [ "${CLAUDE_HOOKS_SAFE_MODE:-0}" = "1" ]; then
  echo "[three-failure-stop-gate] SAFE_MODE active — bypassing gate" >&2
  printf '%s\tthree-failure-stop-gate\tSAFE_MODE-bypass\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 0
fi

bc_write "three-failure-stop-gate-fire" "$(date +%H:%M:%S)"

# ---------------------------------------------------------------------------
# parse_git_commit_args — structural parser (Step B, Codex 2026-05-15).
# Sets GC_IS_COMMIT, GC_REPO_HINT, GC_MSG_BODY, GC_MSG_FILE, GC_HAS_ATTEST
# from $COMMAND and $INPUT.
# ---------------------------------------------------------------------------
parse_git_commit_args() {
  GC_IS_COMMIT="0"; GC_REPO_HINT=""; GC_MSG_BODY=""; GC_MSG_FILE=""; GC_HAS_ATTEST="0"

  if echo "$COMMAND" | grep -qE 'git( -C ("[^"]+"|[^ ]+))? commit'; then
    GC_IS_COMMIT="1"
  fi

  local GITC CDARG CC_CWD
  GITC=$(echo "$COMMAND" | grep -oE 'git -C ("[^"]+"|[^ ]+)' | head -1 \
    | sed -E 's/^git -C //; s/^"(.*)"$/\1/')
  if [ -n "$GITC" ]; then
    GC_REPO_HINT="$GITC"
  else
    CDARG=$(echo "$COMMAND" | grep -oE '(^|[;&(]|&&|\|\|)[[:space:]]*cd[[:space:]]+("[^"]+"|[^ ;&|()]+)' \
      | tail -1 | sed -E 's/.*cd[[:space:]]+//; s/^"(.*)"$/\1/')
    if [ -n "$CDARG" ] && [ "$CDARG" != "-" ]; then
      GC_REPO_HINT="$CDARG"
    fi
  fi
  if [ -z "$GC_REPO_HINT" ]; then
    CC_CWD=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("cwd", ""), end="")
except Exception:
    pass
' 2>/dev/null)
    [ -n "$CC_CWD" ] && GC_REPO_HINT="$CC_CWD"
  fi
  [ -z "$GC_REPO_HINT" ] && GC_REPO_HINT="$PWD"

  GC_MSG_BODY=$(echo "$COMMAND" | grep -oE -- '(-m[[:space:]]+|--message[[:space:]]+|--message=)("[^"]*"|[^ ]+)' | head -1 \
    | sed -E 's/^(-m[[:space:]]+|--message[[:space:]]+|--message=)//; s/^"(.*)"$/\1/')

  GC_MSG_FILE=$(echo "$COMMAND" | grep -oE -- '(-F[[:space:]]+|--file=|--file[[:space:]]+)("[^"]*"|[^ ]+)' | head -1 \
    | sed -E 's/^(-F[[:space:]]+|--file=|--file[[:space:]]+)//; s/^"(.*)"$/\1/')

  if [ -n "$GC_MSG_BODY" ] && echo "$GC_MSG_BODY" | grep -qE '# halted-and-researched:[[:space:]]+[^[:space:]]+'; then
    GC_HAS_ATTEST="1"
  fi
}

parse_git_commit_args
[ "$GC_IS_COMMIT" = "0" ] && exit 0

if [ -z "$GC_MSG_BODY" ]; then
  if [ -n "$GC_MSG_FILE" ]; then
    echo "[three-failure-stop-gate-info] -F/--file= form detected ($GC_MSG_FILE) — gate skipped (F6 documented bypass)" >&2
  fi
  exit 0
fi

if ! echo "$GC_MSG_BODY" | grep -qE 'fix\([^)]*\):'; then
  exit 0
fi

REPO_ROOT=$(git -C "$GC_REPO_HINT" rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  echo "[three-failure-stop-gate-warn] could not resolve target repo — gate disabled. If you've had 3+ recent fix(...) commits and haven't researched, halt and add '# halted-and-researched: <one-line>' to the commit body anyway." >&2
  printf '%s\tthree-failure-stop-gate\trepo-resolve-failed\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 0
fi
REPO=$(basename "$REPO_ROOT")

STAGED=$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null | head -1)
if [ -z "$STAGED" ]; then
  FILE="__unknown__"
else
  FILE=$(echo "$STAGED" | tr '/' '_')
fi

if [ ! -d "$STATE_ROOT" ]; then
  mkdir -p "$STATE_ROOT" 2>/dev/null || {
    echo "[three-failure-stop-gate-warn] could not create $STATE_ROOT; gate disabled" >&2
    exit 0
  }
fi

LOG="$STATE_ROOT/${REPO}__${FILE}.log"
NOW=$(date +%s)
CUTOFF=$((NOW - WINDOW_SECONDS))

PRE_COUNT=$(awk -v cutoff="$CUTOFF" '$1 > cutoff' "$LOG" 2>/dev/null | wc -l | tr -d ' ')
WOULD_BE=$((PRE_COUNT + 1))

if [ "$WOULD_BE" -lt "$THRESHOLD" ]; then
  echo "$NOW" >> "$LOG"
  exit 0
fi

if [ "$GC_HAS_ATTEST" = "1" ]; then
  echo "[three-failure-stop-gate] would-be=#$WOULD_BE — attestation present, allowing" >&2
  echo "$NOW" >> "$LOG"
  exit 0
fi

cat >&2 <<BLOCK
BLOCK: three-failure-stop-gate
This would be fix(...) #$WOULD_BE on $FILE in $REPO within the last 2 hours.

State file: $LOG

Three-Failure Stop (AOF AGENT_FRAMEWORK.md §4):
  "If the same task fails 3 times, halt. Say out loud:
   'This has failed 3 times. I don't understand this system well enough.'
   State what you tried and why each attempt failed. Do not try a 4th
   variation. Research, then retry with evidence."

To override (proceed with research attestation), add this line to your commit body:
    # halted-and-researched: <one-line summary of what you read or learned>

Example:
    git commit -m "\$(cat <<'EOF'
    fix(mcp): load reranker on main thread

    # halted-and-researched: traced FastMCP worker dispatch + torch DLL init thread-safety
    EOF
    )"
BLOCK

bc_write "three-failure-stop-gate-block" "$(date +%H:%M:%S)"
exit 2
