#!/usr/bin/env bash
# aof-eval-opportunity-counter.sh — PreToolUse | SessionStart | UserPromptSubmit
#
# Required env vars (set in settings.json env or shell profile):
#   AOF_EVAL_SUPABASE_URL  — your smokin-ops (or equivalent) Supabase project URL
#   AOF_EVAL_SUPABASE_KEY  — anon key for the above project
#   AOF_EVAL_HOOK_EVENT    — PreToolUse | SessionStart | UserPromptSubmit (default: PreToolUse)
#
# Health check: eval.opportunities rows (NOT telemetry.hook_events fire_count).
# Register three hook_event entries in settings.json — one per event type above.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/breadcrumb-lib.sh" 2>/dev/null || true
HOOK_EVENT="${AOF_EVAL_HOOK_EVENT:-PreToolUse}"
fail_open() {
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "aof-eval-opportunity-counter" "$1" \
    >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 0
}
SUPABASE_URL="${AOF_EVAL_SUPABASE_URL:-}"
SUPABASE_KEY="${AOF_EVAL_SUPABASE_KEY:-}"
MACHINE="$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/darwin/mac/;s/mingw.*/win11/;s/msys.*/win11/')"
insert_opportunity() {
  local rule_id="$1" tool_name="$2" repo_cwd="${3:-}"
  local repo_json="null"
  [[ -n "$repo_cwd" ]] && repo_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$repo_cwd")"
  curl -sf -X POST "${SUPABASE_URL}/rest/v1/opportunities" \
    -H "apikey: ${SUPABASE_KEY}" -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" -H "Accept-Profile: eval" -H "Content-Profile: eval" \
    -H "Prefer: return=minimal" \
    -d "{\"session_id\":\"${SESSION_ID}\",\"tool_name\":\"${tool_name}\",\"rule_id\":\"${rule_id}\",\"repo_cwd\":${repo_json},\"machine\":\"${MACHINE}\"}" \
    --max-time 2 2>/dev/null || printf '%s\taof-eval-opportunity-counter\tsupabase-insert-failed\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
}
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
# Trim whitespace before emptiness check — whitespace-only values pass -z but cause silent insert failures
SUPABASE_URL="${SUPABASE_URL#"${SUPABASE_URL%%[![:space:]]*}"}"
SUPABASE_URL="${SUPABASE_URL%"${SUPABASE_URL##*[![:space:]]}"}"
SUPABASE_KEY="${SUPABASE_KEY#"${SUPABASE_KEY%%[![:space:]]*}"}"
SUPABASE_KEY="${SUPABASE_KEY%"${SUPABASE_KEY##*[![:space:]]}"}"
[[ -z "$SUPABASE_URL" ]] && fail_open "AOF_EVAL_SUPABASE_URL-unset"
[[ -z "$SUPABASE_KEY" ]] && fail_open "AOF_EVAL_SUPABASE_KEY-unset"
[[ -z "$SESSION_ID" ]] && fail_open "session-id-unset"
INPUT="$(cat)"
case "$HOOK_EVENT" in
  SessionStart)
    for rule_id in SS-1 SS-2 SS-3 SS-4 SS-5 SS-6 SS-7 SS-8 SS-9; do
      insert_opportunity "$rule_id" "SessionStart" ""
    done ;;
  UserPromptSubmit)
    for rule_id in "UPS-1" "UPS-2"; do
      insert_opportunity "$rule_id" "UserPromptSubmit" ""
    done ;;
  PreToolUse)
    TOOL_NAME="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)" || fail_open "payload-parse-failed"
    [[ -z "$TOOL_NAME" ]] && fail_open "tool-name-empty"
    REPO_CWD="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || echo "${PWD}")"
    PTU_RULES=(
      "PTU-1|^(Edit|Write|MultiEdit)$" "PTU-2|^(Edit|Write|MultiEdit)$" "PTU-3|^Write$"
      "PTU-4|^(Edit|Write|mcp__.*__execute_sql|mcp__.*__apply_migration)$"
      "PTU-5|^(Edit|Write|mcp__.*__execute_sql|mcp__.*__apply_migration)$"
      "PTU-6|^mcp__mulesoft__search_asset$" "PTU-7|^mcp__mulesoft__(create|generate)"
      "PTU-8|^(Bash|mcp__.*__execute_sql|mcp__.*__apply_migration|mcp__.*__deploy)" "PTU-9|^Bash$"
      "PTU-10|^(Edit|Write|mcp__.*__execute_sql|mcp__.*__apply_migration)$"
      "PTU-11|^(Read|mcp__.*__execute_sql|mcp__.*__list_tables)$"
      "PTU-12|^mcp__claude_ai_Supabase__(execute_sql|apply_migration)$"
      "PTU-15|^mcp__.*__apply_migration$" "PTU-16|^mcp__.*__apply_migration$"
      "PTU-18|^mcp__hindsight__" "PTU-19|^(Edit|Write|Bash|MultiEdit)$"
      "SEC-001|^Bash$" "ARC-001|^(Edit|Write)$" "ARC-002|^(Edit|Write)$"
    )
    for entry in "${PTU_RULES[@]}"; do
      RULE_ID="${entry%%|*}"; PATTERN="${entry#*|}"
      echo "$TOOL_NAME" | grep -qE "$PATTERN" 2>/dev/null && insert_opportunity "$RULE_ID" "$TOOL_NAME" "$REPO_CWD"
    done ;;
  *) fail_open "unknown-hook-event:${HOOK_EVENT}" ;;
esac
exit 0
