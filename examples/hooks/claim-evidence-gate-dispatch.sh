#!/bin/bash
# CLAIM-EVIDENCE GATE DISPATCH — cross-platform front door for Gate 4.
# fail-mode: closed (delegates to a real gate; never silently skips) | blast-radius: Edit|Write|Bash
#
# WHY THIS EXISTS (incident 2026-06-13): the Go binary is per-architecture
# (Mach-O arm64 on Mac). Pointing settings.json directly at it disables the gate
# on any OS where that binary can't execute (e.g. Win11), failing OPEN — the
# worst failure mode for a security gate. This wrapper guarantees a runnable gate
# on EVERY platform:
#   1. Prefer the native binary at ~/.claude/hooks/claim-evidence-gate IF it
#      exists AND is executable AND actually runs on this OS.
#   2. Otherwise fall back to the bash gate (claim-evidence-gate.sh) — same Gate-4
#      behavior, cross-platform, always present.
# The hook payload arrives on stdin and MUST be forwarded intact to whichever gate
# runs. We buffer stdin once and replay it so either path sees the same bytes.
#
# Exit codes are passed through verbatim (0 allow, 2 block) — the wrapper never
# rewrites a block into an allow.
set -euo pipefail
# Git Bash (Win11): this hook invokes a native .exe candidate. No filesystem path
# is passed as an argument (payload is stdin-only), but a Win11-targeted security
# hook ships the guard defensively. (bash-reviewer MED, 2026-06-13.)
export MSYS_NO_PATHCONV=1

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_GATE="${HOOK_DIR}/claim-evidence-gate.sh"
# Telemetry: session-end hook-telemetry-stop.sh counts bc_write breadcrumbs for
# claim-evidence-gate (floor name). Instrument here — the single choke point for
# Go binary + bash fallback — so fire_count is non-zero when the gate runs.
# shellcheck source=breadcrumb-lib.sh
source "${HOOK_DIR}/breadcrumb-lib.sh" 2>/dev/null || true
ceg_telemetry_finish() {
  local rc=$?
  if [ "$rc" -eq 2 ] && command -v bc_write >/dev/null 2>&1; then
    bc_write "claim-evidence-gate-block" "$(date +%H:%M:%S)" 2>/dev/null || true
  fi
  if command -v bc_record_exit >/dev/null 2>&1; then
    bc_record_exit "claim-evidence-gate" "$rc" 2>/dev/null || true
  fi
}
trap ceg_telemetry_finish EXIT
# Normalize cross-runtime envelopes (Grok camelCase toolName/toolInput + tool-name literals
# like search_replace) to Claude Code snake_case BEFORE the gate runs. The Go binary and the
# bash floor both read snake_case tool_input; an un-normalized Grok payload makes the Go binary
# return 0 (no tool_input -> no claim found -> ALLOW), silently BYPASSING Gate 4 on every Grok
# write — a security regression, not just friction. (Grok interop batch 2026-06-15; ports SPG
# #407 pattern.) Fail-open on a missing lib: nh_normalize undefined -> keep raw payload.
source "${HOOK_DIR}/lib/normalize-hook-input.sh" 2>/dev/null || true

# Candidate native-binary names. Windows (Git Bash) needs the .exe; POSIX uses the
# bare name. We probe each: the binary is only trusted if it exists, is executable,
# AND a no-op run actually succeeds on THIS OS — that probe is what catches a
# wrong-architecture binary that is present but cannot execute (the 2026-06-13
# incident: a Mach-O arm64 binary sitting on a machine that can't run it).
BINARY_CANDIDATES=(
  "${HOOK_DIR}/claim-evidence-gate"
  "${HOOK_DIR}/claim-evidence-gate.exe"
)

# Buffer stdin once so we can hand the exact same payload to whichever gate runs.
PAYLOAD="$(cat)"
if command -v bc_write >/dev/null 2>&1; then
  bc_write "claim-evidence-gate-fire" "$(date +%H:%M:%S)" 2>/dev/null || true
fi

# Normalize the buffered payload (Grok camelCase -> Claude snake_case). If the lib failed to
# source, nh_normalize is undefined -> keep PAYLOAD verbatim (fail-open, no regression for
# Claude's already-snake_case shape). nh_normalize fail-opens to its input on bad JSON or
# missing python3, so NORMALIZED is never empty for a non-empty PAYLOAD; the guard is
# belt-and-suspenders.
# Empty stdin -> fail CLOSED. A Gate-4 surface that cannot read its input must BLOCK, not
# allow. This is distinct from a valid envelope whose content field is empty (which the gate
# legitimately allows — nothing to assert). Empty stdin = "the gate saw nothing," which on a
# security surface means block-and-surface, NOT allow. (Grok interop batch 2026-06-15 —
# durable cross-layer posture: wrapper + bash floor + Go binary all fail closed on
# unevaluable input. Matches SPG/HWG empty-stdin posture.)
# Empty OR whitespace-only stdin -> fail CLOSED (Codex Point A 2026-06-15, MED #4). Trim
# leading/trailing whitespace before the emptiness test: a whitespace-only payload is
# unevaluable (no JSON envelope) and must block, not slip through to a gate that finds no
# tool_input and allows. Matches the Go binary's strings.TrimSpace(raw)=="" guard.
PAYLOAD_TRIMMED="${PAYLOAD#"${PAYLOAD%%[![:space:]]*}"}"   # strip leading ws
PAYLOAD_TRIMMED="${PAYLOAD_TRIMMED%"${PAYLOAD_TRIMMED##*[![:space:]]}"}"  # strip trailing ws
if [[ -z "$PAYLOAD_TRIMMED" ]]; then
  echo "[gate4-BLOCK] claim-evidence-gate: empty/whitespace stdin — cannot evaluate. Failing CLOSED." >&2
  echo "[gate4-BLOCK] Source: AOF AGENT_FRAMEWORK.md §4 (Gate 4)" >&2
  printf '%s\tclaim-evidence-gate-dispatch\tempty-stdin-failed-closed-blocked\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 2
fi

if command -v nh_normalize >/dev/null 2>&1; then
  NORMALIZED="$(nh_normalize "$PAYLOAD")"
else
  NORMALIZED="$PAYLOAD"
fi
[[ -n "$NORMALIZED" ]] || NORMALIZED="$PAYLOAD"

# Dual-shape conflict -> fail CLOSED (ports SPG #407 / Codex Point A 2026-06-15). nh_normalize
# emits this sentinel when a payload carries a field in BOTH shapes. Normalizing such a payload
# risks scan/execute divergence — the gate could scan the clean branch while the runtime writes
# the asserting branch. A Gate-4 surface must never allow that, so we BLOCK rather than guess.
if [[ "$NORMALIZED" == "__NH_CONFLICT__" ]]; then
  echo "[gate4-BLOCK] claim-evidence-gate: ambiguous dual-shape payload (camelCase+snake_case key collision)." >&2
  echo "[gate4-BLOCK] Failing CLOSED — cannot guarantee the scanned value matches the executed value." >&2
  printf '%s\tclaim-evidence-gate-dispatch\tdual-shape-conflict-failed-closed-blocked\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 2
fi

# Two-probe trust check (Codex Point A 2026-06-15 MED #3 — mirrors SPG's multi-probe defense).
# A single clean-payload probe trusts a tampered allow-all binary (returns 0 on everything),
# and because a trusted binary suppresses the bash-floor backstop, that binary would wave every
# claim through. So the binary is trusted ONLY if it BOTH:
#   - allows a CLEAN payload (exit 0), AND
#   - blocks a known claim-shaped payload (exit 2).
# A binary that cannot execute returns 126/127 -> not runnable -> fall to the bash floor.
PROBE_CLEAN='{"tool_input":{"file_path":"/nonexistent/__ceg_probe__.txt","content":"probe ok"}}'
# Synthetic claim-shaped payload (assembled so this wrapper file does not itself trip Gate 4).
PROBE_CLAIM="$(printf '{"tool_input":{"content":"the probe %s"}}' 'is wired')"

probe_rc() { local p="$1" b="$2" rc=0; printf '%s' "$p" | "$b" >/dev/null 2>&1 || rc=$?; printf '%s' "$rc"; }

find_runnable_binary() {
  local cand
  for cand in "${BINARY_CANDIDATES[@]}"; do
    [ -x "$cand" ] || continue
    [ "$(probe_rc "$PROBE_CLEAN" "$cand")" = "0" ] || continue   # must allow clean
    [ "$(probe_rc "$PROBE_CLAIM" "$cand")" = "2" ] || continue   # must block a known claim
    printf '%s' "$cand"
    return 0
  done
  return 1
}

if BIN="$(find_runnable_binary)"; then
  # `|| rc=$?` suspends set -e for this pipe so the gate's exit status (2 = a legitimate
  # BLOCK, not a script error) is captured and propagated rather than aborting the wrapper at
  # the pipe. Without the `||`, errexit+pipefail aborts AT the pipe on a non-zero gate exit and
  # the `rc=$?`/`exit "$rc"` lines become dead code (bash-reviewer MED, 2026-06-15 — matches
  # the HWG form). Today the surfaced code is accidentally correct (errexit propagates the
  # pipe's status), but any future line before the exit would silently not run on the BLOCK path.
  rc=0
  printf '%s' "$NORMALIZED" | "$BIN" || rc=$?
  exit "${rc:-0}"  # propagate gate verdict verbatim (0 allow, 2 block)
fi

# Fallback: the bash gate is the cross-platform floor — same Gate-4 behavior on
# any OS without a runnable native binary.
if [ -f "$BASH_GATE" ]; then
  # Same `|| rc=$?` pattern as the binary path — capture+propagate the bash gate's verdict
  # instead of letting errexit abort at the pipe (bash-reviewer MED, 2026-06-15).
  rc=0
  printf '%s' "$NORMALIZED" | bash "$BASH_GATE" || rc=$?
  exit "${rc:-0}"
fi

# No gate available at all (broken install: no runnable binary AND no bash gate).
# fail-mode: CLOSED. A security gate that cannot run must BLOCK, not allow — a
# silent allow here would reproduce the exact 2026-06-13 incident this wrapper
# exists to prevent (a Gate-4 surface failing open). Block loudly and record it.
# (bash-reviewer HIGH, 2026-06-13.)
echo "[gate4-BLOCK] claim-evidence-gate: NO runnable gate found (no native binary, no claim-evidence-gate.sh)." >&2
echo "[gate4-BLOCK] Failing CLOSED — blocking this tool call. Re-run the installer to restore the gate." >&2
printf '%s\tclaim-evidence-gate-dispatch\tNO-GATE-AVAILABLE-failed-closed-blocked\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
exit 2
