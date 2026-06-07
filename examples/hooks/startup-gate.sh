#!/usr/bin/env bash
# fail-mode: open
# blast-radius: advisory
# =============================================================================
# startup-gate.sh — SessionStart hook
#
# Checks all four governance surfaces at session start and writes a drift
# report to ~/.claude/startup-gate-report.md. Session-lifecycle.md Phase 1
# reads that file; if "Action required: yes", Phase 1 surfaces drift items
# before any task begins.
#
# Output contract:
#   1. PRIMARY: writes ~/.claude/startup-gate-report.md
#   2. Emits minimal JSON with a one-line pointer to the report file
#      (additionalContext is NOT the report — it is a pointer)
#   3. g-immutable: this hook MUST NOT write to MEMORY.md, CLAUDE.md,
#      settings.json, or any other instruction surface. The report file is
#      operator-read-only and is never auto-injected.
#
# Why output goes to a file, not additionalContext:
#   Live test (2026-06-07) confirmed that additionalContext injected by a
#   SessionStart hook does NOT surface in fresh sessions — the harness loads
#   the hook output after the system prompt is assembled, so it is invisible
#   to the model on the first turn. File-based output + explicit Phase 1 read
#   is the only reliable pattern.
#
# Seven checks:
#   1. Repo detection (git rev-parse + AGENTS.md presence)
#   2. AGENTS.md verification (identity sentence + procedure section)
#   3. Active plan detection (Status: Active/In Progress in spec/*.md)
#   4. Memory conflict detection (stub — FORGET mechanism pending)
#   5. Skills manifest currency (checks catalog-freshness breadcrumb)
#   6. Hook registration gap (disk vs settings.json diff)
#   7. Conflict resolution (surface precedence summary if drift detected)
#
# Exit semantics: EXIT 0 on ALL paths (informational, never a blocker).
#
# Customization:
#   REPORT_FILE     — where the report is written (default: ~/.claude/startup-gate-report.md)
#   ERRORS_LOG      — fail-open errors log (default: ~/.claude/migration-breadcrumbs/.errors.log)
#   HOOKS_DIR       — directory of installed hooks (default: ~/.claude/hooks)
#   SETTINGS_JSON   — Claude Code settings file (default: ~/.claude/settings.json)
#
# Prerequisites:
#   - breadcrumb-lib.sh (examples/hooks/breadcrumb-lib.sh)
#   - normalize-hook-input.sh (examples/hooks/lib/normalize-hook-input.sh)
#   - python3 in PATH
#
# Hook type: SessionStart (no matcher needed — fires on every session)
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/breadcrumb-lib.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/normalize-hook-input.sh" 2>/dev/null || true

HOME_DIR="${HOME:-$USERPROFILE}"
REPORT_FILE="${REPORT_FILE:-$HOME_DIR/.claude/startup-gate-report.md}"
ERRORS_LOG="${ERRORS_LOG:-$HOME_DIR/.claude/migration-breadcrumbs/.errors.log}"
SETTINGS_JSON="${SETTINGS_JSON:-$HOME_DIR/.claude/settings.json}"
HOOKS_DIR="${HOOKS_DIR:-$HOME_DIR/.claude/hooks}"

log_error() {
  local reason="$1"
  mkdir -p "$(dirname "$ERRORS_LOG")" 2>/dev/null || true
  printf '%s\tstartup-gate\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" \
    >> "$ERRORS_LOG" 2>/dev/null || true
}

# Read and normalize stdin (SessionStart passes a JSON event)
RAW_INPUT=$(cat 2>/dev/null || true)
INPUT=$(nh_normalize "$RAW_INPUT" 2>/dev/null || printf '%s' "$RAW_INPUT")

# Extract CWD from session event
CWD=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('cwd', d.get('session_info', {}).get('cwd', '')))
except Exception:
    print('')
" 2>/dev/null || true)

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DRIFT_COUNT=0
LINES=()

append() { LINES+=("$1"); }

# ── Check 1: Repo detection ──────────────────────────────────────────────────
[ -n "${CWD:-}" ] && [ -d "$CWD" ] && cd "$CWD" 2>/dev/null || true

check1_output="[CHECK 1: FAIL_OPEN — git not available or not in a repo]"
GIT_ROOT=""
REPO_NAME=""
AGENTS_PATH=""
if command -v git >/dev/null 2>&1; then
  GIT_ROOT=$(git --no-pager rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$GIT_ROOT" ]; then
    REPO_NAME=$(basename "$GIT_ROOT")
    AGENTS_PATH="$GIT_ROOT/AGENTS.md"
    if [ -f "$AGENTS_PATH" ]; then
      check1_output="REPO: $REPO_NAME | AGENTS.md: found"
    else
      check1_output="REPO: $REPO_NAME | AGENTS.md: NOT FOUND — cold start without repo governance"
      (( DRIFT_COUNT++ )) || true
    fi
  else
    REPO_NAME="no-git-repo"
    check1_output="REPO: (not in a git repo) | CWD: ${CWD:-unknown}"
  fi
else
  log_error "check1-git-not-found"
fi
append "**Check 1 — Repo:** $check1_output"

# ── Check 2: AGENTS.md verification ─────────────────────────────────────────
if [ -n "${AGENTS_PATH:-}" ] && [ -f "$AGENTS_PATH" ]; then
  IDENTITY=$(head -3 "$AGENTS_PATH" 2>/dev/null | head -1 | sed 's/^#* *//' || true)
  HAS_PROCEDURE=$(grep -qiE "^#{1,3}.*(procedure|checklist|numbered|step)" \
    "$AGENTS_PATH" 2>/dev/null && echo "found" || echo "not found")
  check2_output="identity: ${IDENTITY:0:80} | Procedure section: $HAS_PROCEDURE"
else
  check2_output="(skipped — no AGENTS.md)"
fi
append "**Check 2 — AGENTS.md:** $check2_output"

# ── Check 3: Active plan detection ──────────────────────────────────────────
ACTIVE_PLAN="none found"
SEARCH_DIRS=()
[ -n "${GIT_ROOT:-}" ] && SEARCH_DIRS+=("$GIT_ROOT/spec" "$GIT_ROOT/docs/plans")
SEARCH_DIRS+=("$HOME_DIR/.claude/plans")

for dir in "${SEARCH_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    found=$(grep -rl --include="*.md" -E \
      "^(Status|status):[[:space:]]*(Active|In Progress)" \
      "$dir" 2>/dev/null | head -1 || true)
    if [ -n "$found" ]; then
      ACTIVE_PLAN="$(basename "$found")"
      break
    fi
  fi
done
append "**Check 3 — Active plan:** $ACTIVE_PLAN"

# ── Check 4: Memory conflict detection (stub) ───────────────────────────────
append "**Check 4 — Memory conflicts:** deferred (FORGET mechanism pending — manual reconciliation path: reconcile-memory.sh)"

# ── Check 5: Skills manifest currency ────────────────────────────────────────
check5_output="skills manifest: (catalog-freshness script not found)"
CATALOG_BC="$HOOKS_DIR/catalog-freshness.sh"
if [ -f "$CATALOG_BC" ]; then
  CATALOG_OUT=$(echo '{}' | bash "$CATALOG_BC" 2>&1 || true)
  if echo "$CATALOG_OUT" | grep -qi "stale\|warn\|out of date"; then
    check5_output="skills manifest: STALE — catalog-freshness advisory fired"
    (( DRIFT_COUNT++ )) || true
  else
    check5_output="skills manifest: current"
  fi
fi
append "**Check 5 — Skills:** $check5_output"

# ── Check 6: Hook registration gap ──────────────────────────────────────────
check6_output="[CHECK 6: FAIL_OPEN]"
if [ -f "$SETTINGS_JSON" ] && command -v python3 >/dev/null 2>&1; then
  GAP_OUTPUT=$(python3 - "$HOOKS_DIR" "$SETTINGS_JSON" << 'PYEOF'
import json, os, sys, re

hooks_dir = sys.argv[1]
settings_path = sys.argv[2]

# Hook scripts on disk that declare REQUIRED registration
on_disk = set()
if os.path.isdir(hooks_dir):
    for fname in os.listdir(hooks_dir):
        if not fname.endswith('.sh'):
            continue
        fpath = os.path.join(hooks_dir, fname)
        try:
            with open(fpath, encoding='utf-8', errors='replace') as f:
                content = f.read(4096)
            if '# REQUIRED settings.json registration' in content:
                on_disk.add(fname)
        except Exception:
            pass

# Scripts registered in settings.json
registered = set()
try:
    with open(settings_path) as f:
        s = json.load(f)
    hooks_block = s.get('hooks', {})
    for event_hooks in hooks_block.values():
        for entry in event_hooks:
            for h in entry.get('hooks', []):
                cmd = h.get('command', '')
                m = re.search(r'(\w[\w.-]+\.sh)', cmd)
                if m:
                    registered.add(m.group(1))
except Exception:
    pass

# Known libraries and cron scripts — not hooks, exclude from gap reporting
not_hooks = {
    'breadcrumb-lib.sh',
    'normalize-hook-input.sh',
}

unregistered = sorted((on_disk - registered) - not_hooks)
print(f"{len(on_disk)} requiring-registration | {len(registered)} registered | unregistered: {', '.join(unregistered) if unregistered else 'none'}")
PYEOF
  ) || { GAP_OUTPUT="FAIL_OPEN — python3 parse error"; log_error "check6-python-parse-error"; }

  if echo "$GAP_OUTPUT" | grep -q "unregistered: [a-z]"; then
    (( DRIFT_COUNT++ )) || true
  fi
  check6_output="$GAP_OUTPUT"
else
  log_error "check6-settings-or-python-missing"
fi
append "**Check 6 — Hook registration:** $check6_output"

# ── Check 7: Conflict summary ────────────────────────────────────────────────
if [ "$DRIFT_COUNT" -gt 0 ]; then
  append "**Check 7 — Surface precedence:** $DRIFT_COUNT drift item(s) detected. Resolution order: Hooks > AGENTS.md > Plan > Skills > Memory > Inference. FORGET mechanism is not yet live — manual review required."
else
  append "**Check 7 — Conflicts:** none detected"
fi

# ── Write the report file ────────────────────────────────────────────────────
{
  echo "# Startup Gate Report — $TS"
  echo ""
  for line in "${LINES[@]}"; do
    echo "$line"
  done
  echo ""
  echo "---"
  if [ "$DRIFT_COUNT" -gt 0 ]; then
    echo "Drift detected: $DRIFT_COUNT item(s) | Action required: yes"
  else
    echo "Drift detected: 0 | Action required: no"
  fi
} > "$REPORT_FILE" 2>/dev/null || log_error "report-write-failed"

# ── Emit minimal JSON (pointer to report, not the report content) ────────────
python3 -c "
import json
drift = $DRIFT_COUNT
msg = 'Startup gate ran — see ~/.claude/startup-gate-report.md'
if drift > 0:
    msg = f'[ACTION REQUIRED] Startup gate found {drift} drift item(s) — read startup-gate-report.md before starting task'
print(json.dumps({
    'hookEventName': 'SessionStart',
    'hookSpecificOutput': {
        'additionalContext': msg
    }
}))
" 2>/dev/null || true

exit 0
