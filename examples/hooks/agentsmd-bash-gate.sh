#!/usr/bin/env bash
# agentsmd-bash-gate.sh
# PreToolUse hook (matcher: Bash) — blocks Bash commands that touch ~/repos/<name>/
# unless AGENTS.md for that repo has been Read this session.
# Complements new-repo-read-gate.sh which covers Edit|MultiEdit|Write.
# Exits 2 to block; exits 0 to allow.
# fail-mode: open (parse errors allow through — don't block on bad JSON)
# blast-radius: local session only — read-only check, no writes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/breadcrumb-lib.sh" 2>/dev/null || { exit 0; }
source "$SCRIPT_DIR/lib/normalize-hook-input.sh" 2>/dev/null || true

INPUT="${HOOK_INPUT_JSON:-$(cat)}"

# Normalize camelCase (Grok) → snake_case (Claude Code) before any field extraction.
# Without this, Grok-shaped payloads (toolInput instead of tool_input) exit 0 silently.
# __NH_CONFLICT__: dual-shape payload — fail closed. The gate cannot safely evaluate
# which branch the runtime will execute; allowing risks bypassing on a Grok+Claude
# dual-envelope payload crafted to carry a repo command in the Grok branch only.
if command -v nh_normalize >/dev/null 2>&1; then
  INPUT="$(nh_normalize "$INPUT")"
  if [ "$INPUT" = "__NH_CONFLICT__" ]; then
    printf "[GATE: agentsmd-bash] dual-shape payload conflict — failing closed.\n" >&2
    exit 2
  fi
fi

# Extract command string from Bash tool input
COMMAND="$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Prefer tool_input (Claude Code shape); fall back to input for legacy envelopes
    obj = d.get('tool_input', d.get('input', d))
    print(obj.get('command', '') if isinstance(obj, dict) else '')
except Exception:
    print('')
" 2>/dev/null)"

[ -z "$COMMAND" ] && exit 0

# Only gate commands that reference a local repo path
# Match $HOME/repos/<name> or ~/repos/<name> or /Users/<user>/repos/<name>
REPO_NAME=""
for pattern in \
    "$HOME/repos/" \
    "~/repos/" \
    "/Users/[^/]*/repos/"; do
    # Try to extract repo name from the command string
    REPO_NAME="$(echo "$COMMAND" | grep -oE "(${HOME}|~|/Users/[^/]+)/repos/[^/[:space:]'\"]+" 2>/dev/null | head -1 | sed -E 's|.*/repos/([^/[:space:]]+).*|\1|' || true)"
    [ -n "$REPO_NAME" ] && break
done

[ -z "$REPO_NAME" ] && exit 0  # No repo path in command — allow

# Allow AGENTS.md reads themselves through (breadcrumb not yet written when gate fires).
# Scope: only commands whose sole purpose is reading AGENTS.md for this repo.
# Broad substring match (old) allowed "echo AGENTS.md; ls ~/repos/target/" to bypass.
# Fixed: require the command to reference AGENTS.md at the target repo path specifically,
# not just contain "AGENTS.md" anywhere in the string.
AGENTS_PATH="$HOME/repos/$REPO_NAME/AGENTS.md"
# Allow only commands that reference the specific AGENTS.md path for THIS repo.
# Broad pattern matching (any command containing "AGENTS.md") was bypassable via
# "cat /other/repo/AGENTS.md; <dangerous command targeting $REPO_NAME>".
# Fix: anchor to $AGENTS_PATH only. The anchored grep below is the sole allow path.
if echo "$COMMAND" | grep -qF "$AGENTS_PATH"; then
  exit 0
fi

# Check breadcrumb
LOG_FILE="$(bc_dir)/$(bc_session_key)-new-repo-read-log"

if [ ! -f "$LOG_FILE" ] || ! grep -qF $'\t'"$REPO_NAME"$'\t'"AGENTS.md" "$LOG_FILE" 2>/dev/null; then
    printf "[GATE: agentsmd-bash] AGENTS.md not read for repo '%s' this session. Read it before running Bash commands in this repo.\n" "$REPO_NAME" >&2
    exit 2
fi

exit 0
