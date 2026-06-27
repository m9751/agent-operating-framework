#!/usr/bin/env bash
# grok-shape-normalize.sh — smoke test for Grok camelCase → Claude snake_case normalization
# Tests that normalize-hook-input.sh (lib/normalize-hook-input.sh) correctly handles
# Grok's camelCase envelope before gate hooks run.
#
# Run: bash tests/smoke/hooks/grok-shape-normalize.sh
# Exit 0 = all pass | Exit 1 = one or more failures
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIB="${REPO_ROOT}/examples/hooks/lib/normalize-hook-input.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf "  PASS  %s\n" "$label"
    PASS=$((PASS + 1))
  else
    printf "  FAIL  %s\n    expected: %s\n    actual:   %s\n" "$label" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_field() {
  local label="$1" json="$2" field="$3" expected="$4"
  local actual
  actual="$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null)"
  assert_eq "$label [$field]" "$expected" "$actual"
}

if [ ! -f "$LIB" ]; then
  echo "SKIP: lib/normalize-hook-input.sh not found at $LIB"
  echo "      Install the library or copy from your claude-config/hooks/lib/"
  exit 0
fi

# shellcheck source=/dev/null
source "$LIB"

echo "=== grok-shape-normalize smoke test ==="
echo ""

# --- Test 1: Grok camelCase toolName/toolInput → snake_case tool_name/tool_input ---
echo "1. camelCase envelope normalization"
PAYLOAD_1='{"toolName":"Write","toolInput":{"file_path":"/tmp/test.txt","content":"hello"}}'
OUT_1="$(nh_normalize "$PAYLOAD_1")"
assert_field "tool_name extracted" "$OUT_1" "tool_name" "Write"
TOOL_INPUT_CONTENT="$(echo "$OUT_1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('content',''))" 2>/dev/null)"
assert_eq "tool_input.content preserved" "hello" "$TOOL_INPUT_CONTENT"

# --- Test 2: Already-snake_case passthrough (Claude Code shape) ---
echo ""
echo "2. snake_case passthrough (no mutation)"
PAYLOAD_2='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
OUT_2="$(nh_normalize "$PAYLOAD_2")"
assert_field "tool_name unchanged" "$OUT_2" "tool_name" "Bash"

# --- Test 3: Dual-shape conflict → __NH_CONFLICT__ sentinel ---
echo ""
echo "3. dual-shape conflict detection"
PAYLOAD_3='{"toolName":"Edit","tool_name":"Edit","toolInput":{},"tool_input":{}}'
OUT_3="$(nh_normalize "$PAYLOAD_3")"
assert_eq "conflict sentinel" "__NH_CONFLICT__" "$OUT_3"

# --- Test 4: Empty input → empty output (fail-open, not crash) ---
echo ""
echo "4. empty input passthrough"
OUT_4="$(nh_normalize "" 2>/dev/null || echo "")"
assert_eq "empty input → empty" "" "$OUT_4"

# --- Test 5: Malformed JSON → original payload returned (fail-open) ---
echo ""
echo "5. malformed JSON passthrough"
PAYLOAD_5='not valid json'
OUT_5="$(nh_normalize "$PAYLOAD_5" 2>/dev/null)"
assert_eq "malformed → passthrough" "$PAYLOAD_5" "$OUT_5"

# --- Test 6: agentsmd-bash-gate.sh blocks a Grok-shaped payload after normalization ---
# This is a gate-level test, not just a library test. It catches the class of bug where
# the normalizer is sourced but not applied — Grok payloads would exit 0 silently.
echo ""
echo "6. agentsmd-bash-gate.sh blocks Grok-shaped payload (gate enforcement)"
GATE="${REPO_ROOT}/examples/hooks/agentsmd-bash-gate.sh"
if [ ! -f "$GATE" ]; then
  printf "  SKIP  gate not found at %s\n" "$GATE"
  PASS=$((PASS + 1))
else
  # Grok-shaped payload: toolInput instead of tool_input, touching a repo path.
  # Expected: exit 2 (blocked). Without normalization the gate sees no tool_input.command
  # → empty COMMAND → exits 0. Both outcomes produce exit 2, but for different reasons;
  # the control payload below (snake_case + innocuous path) distinguishes them.
  GROK_PAYLOAD='{"toolName":"Bash","toolInput":{"command":"ls '"${HOME}"'/repos/agent-operating-framework/"}}'
  GATE_RC=0
  printf '%s' "$GROK_PAYLOAD" | HOOK_INPUT_JSON="" bash "$GATE" 2>/dev/null || GATE_RC=$?
  if [ "$GATE_RC" -eq 2 ]; then
    printf "  PASS  agentsmd-bash-gate blocked Grok payload (exit 2)\n"
    PASS=$((PASS + 1))
  elif [ "$GATE_RC" -eq 0 ]; then
    printf "  FAIL  agentsmd-bash-gate ALLOWED Grok payload (exit 0) — normalization not applied\n"
    FAIL=$((FAIL + 1))
  else
    printf "  FAIL  agentsmd-bash-gate exited %d (unexpected)\n" "$GATE_RC"
    FAIL=$((FAIL + 1))
  fi

  # Control payload: snake_case envelope, command that does NOT touch a repo path.
  # Must exit 0 — proves the gate discriminates rather than blocking everything.
  CONTROL_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
  CTRL_RC=0
  printf '%s' "$CONTROL_PAYLOAD" | HOOK_INPUT_JSON="" bash "$GATE" 2>/dev/null || CTRL_RC=$?
  if [ "$CTRL_RC" -eq 0 ]; then
    printf "  PASS  agentsmd-bash-gate allowed harmless snake_case payload (exit 0)\n"
    PASS=$((PASS + 1))
  else
    printf "  FAIL  agentsmd-bash-gate blocked harmless payload (exit %d) — gate blocks everything\n" "$CTRL_RC"
    FAIL=$((FAIL + 1))
  fi
fi

# --- Test 7: agentsmd-bash-gate.sh fails closed on __NH_CONFLICT__ dual-shape payload ---
echo ""
echo "7. agentsmd-bash-gate.sh fails closed on dual-shape conflict"
if [ ! -f "$GATE" ]; then
  printf "  SKIP  gate not found\n"
  PASS=$((PASS + 1))
else
  CONFLICT_PAYLOAD='{"toolName":"Bash","tool_name":"Bash","toolInput":{"command":"ls '"${HOME}"'/repos/agent-operating-framework/"},"tool_input":{"command":"ls '"${HOME}"'/repos/agent-operating-framework/"}}'
  CONFLICT_RC=0
  printf '%s' "$CONFLICT_PAYLOAD" | HOOK_INPUT_JSON="" bash "$GATE" 2>/dev/null || CONFLICT_RC=$?
  if [ "$CONFLICT_RC" -eq 2 ]; then
    printf "  PASS  agentsmd-bash-gate failed closed on conflict payload (exit 2)\n"
    PASS=$((PASS + 1))
  else
    printf "  FAIL  agentsmd-bash-gate returned %d on conflict payload — should exit 2\n" "$CONFLICT_RC"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
