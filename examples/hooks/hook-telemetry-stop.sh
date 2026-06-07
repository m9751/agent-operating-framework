#!/usr/bin/env bash
# fail-mode: open
# blast-radius: advisory
# =============================================================================
# hook-telemetry-stop.sh — Stop hook (session-end telemetry writer)
#
# Runs at session end. Reads per-hook fire and block breadcrumbs written by
# blocking hooks during the session, then bulk-INSERTs one row per hook into
# a telemetry table via the Supabase REST API.
#
# This answers v1.6's "are hooks theater?" question with operational data:
# after 2 weeks of deployment you can query fire_count and block_count per
# hook and know which gates are actually firing.
#
# Prerequisites:
#   - breadcrumb-lib.sh (examples/hooks/breadcrumb-lib.sh)
#   - AOF_TELEMETRY_URL env var — your Supabase project URL
#   - AOF_TELEMETRY_KEY env var — a low-privilege anon/service key with
#     INSERT permission on the telemetry table (see Schema below)
#   - python3 in PATH
#
# Schema (create this table before enabling the hook):
#
#   CREATE TABLE telemetry.hook_events (
#     id            bigserial PRIMARY KEY,
#     session_id    text      NOT NULL,
#     hook_name     text      NOT NULL,
#     fire_count    integer   NOT NULL DEFAULT 0,
#     block_count   integer   NOT NULL DEFAULT 0,
#     safe_mode_used boolean  NOT NULL DEFAULT false,
#     session_date  date      NOT NULL,
#     machine       text,
#     created_at    timestamptz NOT NULL DEFAULT now()
#   );
#   ALTER TABLE telemetry.hook_events ENABLE ROW LEVEL SECURITY;
#   -- RLS: allow anon INSERT, deny all reads from anon
#   CREATE POLICY "anon_insert" ON telemetry.hook_events
#     FOR INSERT TO anon WITH CHECK (true);
#
# Breadcrumb contract:
#   Each blocking hook writes a breadcrumb on fire:  bc_write "<hook>-fire"
#   Each blocking hook writes a breadcrumb on block: bc_write "<hook>-block"
#   This hook counts lines in each breadcrumb file to get fire/block counts.
#
# BLOCKING_HOOKS: customize this list to match the hooks you have installed.
#   Only hooks that write breadcrumbs will produce meaningful counts.
#   Hooks not in this list are silently omitted from telemetry.
#
# SAFE_MODE:
#   If CLAUDE_HOOKS_SAFE_MODE=1 was active during the session, that fact
#   is recorded as safe_mode_used=true for every hook row.
#
# Exit semantics: EXIT 0 on all paths (advisory, never blocks session close).
#
# Hook type: Stop (no matcher — fires on every session end)
# =============================================================================

# H1: no set -e — fail-open advisory hook; unhandled errors must not block close
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/breadcrumb-lib.sh" 2>/dev/null || true

ERRORS_LOG="${HOME:-$USERPROFILE}/.claude/migration-breadcrumbs/.errors.log"

if ! command -v bc_session_key >/dev/null 2>&1; then
  echo "[hook-telemetry] WARN: breadcrumb-lib.sh not loaded — skipping telemetry" >&2
  printf '%s\thook-telemetry-stop\tbreadcrumb-lib-load-failed\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ERRORS_LOG" 2>/dev/null || true
  exit 0
fi

# ── Config ────────────────────────────────────────────────────────────────────
# Set AOF_TELEMETRY_URL and AOF_TELEMETRY_KEY in your environment.
# Example (add to ~/.claude/env or your shell profile):
#   export AOF_TELEMETRY_URL="https://<your-project>.supabase.co"
#   export AOF_TELEMETRY_KEY="<anon-key-with-insert-only-rls>"
TELEMETRY_URL="${AOF_TELEMETRY_URL:-}"
TELEMETRY_KEY="${AOF_TELEMETRY_KEY:-}"

if [ -z "$TELEMETRY_URL" ] || [ -z "$TELEMETRY_KEY" ]; then
  echo "[hook-telemetry] WARN: AOF_TELEMETRY_URL or AOF_TELEMETRY_KEY not set — skipping" >&2
  printf '%s\thook-telemetry-stop\ttelemetry-env-vars-not-set\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ERRORS_LOG" 2>/dev/null || true
  exit 0
fi

# ── Customize: list the blocking hooks you have installed ────────────────────
BLOCKING_HOOKS=(
  "read-gate"
  "search-gate"
  "delivery-gate"
  "secure-config-gate"
  "focus-confirmation-gate"
  "dormant-code-gate"
  "empty-rule-body-gate"
)

# ── Session identity ──────────────────────────────────────────────────────────
SESSION_ID=$(bc_session_key 2>/dev/null) || SESSION_ID="unknown-$$"
BC_DIR=$(bc_dir 2>/dev/null) || BC_DIR="/tmp/claude-hooks-${USER:-unknown}"
SESSION_DATE=$(date +%Y-%m-%d)
SAFE_MODE="${CLAUDE_HOOKS_SAFE_MODE:-0}"
SAFE_MODE_FLAG="false"
[ "$SAFE_MODE" = "1" ] && SAFE_MODE_FLAG="true"

MACHINE="unknown"
case "$(uname -s 2>/dev/null || true)" in
  Darwin) MACHINE="mac" ;;
  Linux)  MACHINE="linux" ;;
  CYGWIN*|MINGW*|MSYS*) MACHINE="win11" ;;
esac

# ── Count fires and blocks per hook ──────────────────────────────────────────
count_breadcrumb() {
  local file="$1"
  local n
  if [ -f "$file" ]; then
    n=$(wc -l < "$file" | tr -d ' ')
    [[ "$n" =~ ^[0-9]+$ ]] && echo "$n" || echo "0"
  else
    echo "0"
  fi
}

json_escape() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$1"
}

# ── Build JSON rows ───────────────────────────────────────────────────────────
SESSION_ID_JSON=$(json_escape "$SESSION_ID")
MACHINE_JSON=$(json_escape "$MACHINE")

ROWS="["
FIRST=1
for HOOK in "${BLOCKING_HOOKS[@]}"; do
  FIRE_FILE="${BC_DIR}/${SESSION_ID}-${HOOK}-fire"
  BLOCK_FILE="${BC_DIR}/${SESSION_ID}-${HOOK}-block"
  FIRES=$(count_breadcrumb "$FIRE_FILE")
  BLOCKS=$(count_breadcrumb "$BLOCK_FILE")
  HOOK_JSON=$(json_escape "$HOOK")

  ROW="{\"session_id\":${SESSION_ID_JSON},\"hook_name\":${HOOK_JSON},\"fire_count\":${FIRES},\"block_count\":${BLOCKS},\"safe_mode_used\":${SAFE_MODE_FLAG},\"session_date\":\"${SESSION_DATE}\",\"machine\":${MACHINE_JSON}}"

  if [ "$FIRST" -eq 1 ]; then
    ROWS="${ROWS}${ROW}"
    FIRST=0
  else
    ROWS="${ROWS},${ROW}"
  fi
done
ROWS="${ROWS}]"

# ── POST to Supabase REST ─────────────────────────────────────────────────────
TMPFILE=$(mktemp /tmp/hook-telemetry-XXXXXX.txt 2>/dev/null) || TMPFILE="/tmp/hook-telemetry-$$.txt"
trap 'rm -f "$TMPFILE"' EXIT

HTTP_STATUS=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  -X POST \
  -H "apikey: ${TELEMETRY_KEY}" \
  -H "Authorization: Bearer ${TELEMETRY_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept-Profile: telemetry" \
  -H "Content-Profile: telemetry" \
  -H "Prefer: return=minimal" \
  "${TELEMETRY_URL}/rest/v1/hook_events" \
  -d "$ROWS" 2>/dev/null) || HTTP_STATUS="000"

if [ "$HTTP_STATUS" = "201" ]; then
  echo "[hook-telemetry] session ${SESSION_ID} → ${#BLOCKING_HOOKS[@]} hook rows written (${SESSION_DATE})" >&2
elif [ "$HTTP_STATUS" = "000" ]; then
  echo "[hook-telemetry] WARN: curl failed — no network or telemetry endpoint unreachable" >&2
else
  BODY=$(cat "$TMPFILE" 2>/dev/null | head -c 200)
  echo "[hook-telemetry] WARN: HTTP ${HTTP_STATUS} — ${BODY}" >&2
fi

exit 0
