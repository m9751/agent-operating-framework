#!/usr/bin/env bash
# agentsmd-session-inject.sh
# SessionStart hook — when cwd is ~/repos/<name>/, reads AGENTS.md and prints
# it to stdout so Claude loads it as session context before any user prompt.
# Advisory only: does not block; agent may still ignore content.
# fail-mode: open (errors print nothing — don't corrupt session start)
# blast-radius: read-only, local session only
set -euo pipefail

CWD="${CLAUDE_CWD:-$(pwd)}"

# Normalize home dir
CWD="${CWD/#\~/$HOME}"

# Only fire when cwd is directly inside ~/repos/<name> (one level deep)
case "$CWD" in
    "$HOME/repos/"*)
        REPO_NAME="$(echo "$CWD" | sed -E "s|$HOME/repos/([^/]+).*|\1|")"
        AGENTS_MD="$HOME/repos/$REPO_NAME/AGENTS.md"
        ;;
    "/Users/"*"/repos/"*)
        REPO_NAME="$(echo "$CWD" | sed -E 's|/Users/[^/]+/repos/([^/]+).*|\1|')"
        AGENTS_MD="$(echo "$CWD" | sed -E 's|(/Users/[^/]+/repos/[^/]+).*|\1|')/AGENTS.md"
        ;;
    *)
        exit 0
        ;;
esac

[ -z "$REPO_NAME" ] && exit 0
[ ! -f "$AGENTS_MD" ] && exit 0

printf '=== SESSION START: AGENTS.md for %s ===\n' "$REPO_NAME"
cat "$AGENTS_MD"
printf '=== END AGENTS.md ===\n'

exit 0
