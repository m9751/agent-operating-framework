#!/bin/bash
# CLAIM-EVIDENCE GATE — Gate 4 of read-before-acting.md
# fail-mode: closed (blocking) | blast-radius: blocks Edit|Write|Bash with assertion language
# PreToolUse hook on Edit|Write|Bash. Exits 2 to block when assertion language detected.
#
# Scans tool input for assertion-language keywords ("is wired", "is complete",
# "fully integrated", "the data shows", "directory contains only", "confirmed",
# "verified", "is done", "functionality is"). When a hit fires, blocks the write.
#
# Phase B (2026-06-12): explicit "VERIFIED against `<path>`" claims require a
# matching READ breadcrumb for that path in the current session (T4 fabrication
# guard — bloomberg-terminal incident 2026-05-27).
#
# Pattern matches Gate 4 enforcement design in ~/.claude/rules/read-before-acting.md
# Session read log: /tmp/claude-hooks-${USER}/$(bc_session_key)-reads-log
# populated by no-guess-breadcrumb.sh on Read calls.
#
# Companion: ~/.claude/hooks/no-guess-gate.sh (Gate 3, blocking, infra mutations)
# Source rule: AOF AGENT_FRAMEWORK.md §4 (Gate 4)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=breadcrumb-lib.sh
source "$SCRIPT_DIR/breadcrumb-lib.sh" 2>/dev/null || true

INPUT=$(cat)

# Empty stdin -> fail CLOSED. A Gate-4 surface that cannot read its input at all must BLOCK,
# not allow. This is distinct from a valid envelope whose content field is empty (handled at
# the TEXT-empty check below, which legitimately allows — nothing to assert). Empty stdin means
# the gate saw nothing, which on a security surface is block-and-surface. (Grok interop batch
# 2026-06-15 — durable cross-layer posture: dispatch wrapper + this bash floor + the Go binary
# all fail closed on unevaluable input. Matches SPG/HWG.)
INPUT_TRIMMED="${INPUT#"${INPUT%%[![:space:]]*}"}"
INPUT_TRIMMED="${INPUT_TRIMMED%"${INPUT_TRIMMED##*[![:space:]]}"}"
if [ -z "$INPUT_TRIMMED" ]; then
  echo "[gate4-BLOCK] claim-evidence-gate: empty/whitespace stdin — cannot evaluate. Failing CLOSED." >&2
  echo "[gate4-BLOCK] Source: AOF AGENT_FRAMEWORK.md §4 (Gate 4)" >&2
  printf '%s\tclaim-evidence-gate\tempty-stdin-failed-closed-blocked\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 2
fi

# Path normalizer (hoisted above its first use — the allowlist below + the
# reads-log matcher both call it). Backslash->slash and /c/ -> C:/ for Win11.
ceg_normalize_path() {
  echo "$1" | tr '\\' '/' | sed -E 's#^/([a-zA-Z])/#\1:/#'
}

# Skip .go source files — regex string literals in Go source legitimately
# contain assertion words (confirmed, verified, etc.) that are not Gate 4 claims.
FILE_PATH=$(echo "$INPUT" | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"([^"]+\.go)"' | head -1 | grep -oE '"[^"]+\.go"' | tr -d '"' || true)
if [ -n "$FILE_PATH" ]; then
  exit 0
fi

# Path-allowlist (2026-06-16 — Gate-4 PreToolUse regression fix). Mirrors the
# SPG/HWG dual-layer allowlist: files that legitimately QUOTE assertion phrases
# while documenting or implementing the gate must not be blocked when the gate is
# wired blocking under PreToolUse. Without this, CEG self-blocks edits to its own
# source + the rule files that cite its banned tokens (reproduced 2026-06-16).
# Root-anchored on a normalized path so a crafted /tmp/.claude/rules/... cannot
# exempt. Any tool_input path (file_path OR path) is extracted and normalized via
# the same ceg_normalize_path used for the reads-log, then matched against the set.
ALLOW_PATH=$(echo "$INPUT" | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"([^"]+)"' | head -1 | sed -E 's/^"(file_path|path)"[[:space:]]*:[[:space:]]*"(.*)"$/\2/' || true)
if [ -n "$ALLOW_PATH" ]; then
  NORM_ALLOW=$(ceg_normalize_path "$ALLOW_PATH")
  HOME_NORM=$(ceg_normalize_path "$HOME")
  # Root-anchored exempt patterns (both installed ~/.claude/ and repo claude-config forms).
  CEG_ALLOWLIST=(
    "^${HOME_NORM}/\.claude/hooks/claim-evidence-gate(\.sh|-dispatch\.sh)?$"
    "^${HOME_NORM}/repos/claude-config/hooks/claim-evidence-gate(\.sh|-dispatch\.sh)?$"
    "^${HOME_NORM}/repos/agent-operating-framework/examples/hooks/claim-evidence-gate(\.sh|-dispatch\.sh)?$"
    "^${HOME_NORM}/\.claude/law/[^/]+\.md$"
    "^${HOME_NORM}/repos/claude-config/law/[^/]+\.md$"
  )
  for pat in "${CEG_ALLOWLIST[@]}"; do
    if echo "$NORM_ALLOW" | grep -qE "$pat"; then
      printf '%s\tclaim-evidence-gate\tpath-allowlisted-allow\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
      exit 0
    fi
  done
fi

# Extract candidate text from tool input. Different tools store the
# user-authored payload in different fields:
#   Write   → tool_input.content
#   Edit    → tool_input.new_string
#   Bash    → tool_input.command
TEXT=""
for FIELD in "content" "new_string" "command"; do
  CHUNK=$(echo "$INPUT" | grep -oE "\"$FIELD\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" | head -1 | sed -E "s/^\"$FIELD\"[[:space:]]*:[[:space:]]*\"(.*)\"$/\\1/")
  if [ -n "$CHUNK" ]; then
    TEXT="$TEXT $CHUNK"
  fi
done

# Bail if nothing to scan
if [ -z "$TEXT" ]; then
  printf '%s\tclaim-evidence-gate\tTEXT-empty\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 0
fi

ceg_path_was_read() {
  local claim_path="$1"
  local reads_log
  reads_log="$(bc_dir)/$(bc_session_key)-reads-log"
  [ -f "$reads_log" ] || return 1

  local norm_claim
  norm_claim=$(ceg_normalize_path "$claim_path")
  # (ceg_normalize_path is defined near the top of the script — see hoisted def.)

  while IFS= read -r line; do
    case "$line" in
      *" READ "*) ;;
      *) continue ;;
    esac
    local read_path="${line#* READ }"
    local norm_read
    norm_read=$(ceg_normalize_path "$read_path")
    if [ "$norm_read" = "$norm_claim" ]; then
      return 0
    fi
    if echo "$norm_read" | grep -qiF "$norm_claim"; then
      return 0
    fi
    if echo "$norm_claim" | grep -qiF "$norm_read"; then
      return 0
    fi
  done < "$reads_log"
  return 1
}

ceg_path_exists() {
  local p="$1"
  [ -f "$p" ] && return 0
  local msys
  msys=$(echo "$p" | sed -E 's#^([A-Za-z]):#/\L\1#' | tr '\\' '/')
  [ -n "$msys" ] && [ -f "$msys" ] && return 0
  return 1
}

ceg_block() {
  local reason="$1"
  local detail="$2"
  cat >&2 <<BLOCK
[gate4-BLOCK] ${reason}
[gate4-BLOCK] ${detail}
[gate4-BLOCK] Gate 4 / T4: verification records require a session Read of the cited path.
[gate4-BLOCK] Proxy evidence (handoff, MEMORY, hindsight, SoR prose without Read) is not verification.
[gate4-BLOCK] Downgrade to the actual result (e.g. "verification deferred") or Read the file first.
[gate4-BLOCK] Source: AOF AGENT_FRAMEWORK.md §4 (Gate 4)
BLOCK
  printf '%s\tclaim-evidence-gate\tBLOCKED: %s — %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" "$detail" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
  exit 2
}

# Phase B: block explicit verification claims that cite a path without a Read breadcrumb.
VERIFY_PATHS=""
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  path=$(echo "$hit" | sed -E 's/.*`([^`]+)`.*/\1/')
  [ -n "$path" ] && VERIFY_PATHS="${VERIFY_PATHS}${path}"$'\n'
done < <(echo "$TEXT" | grep -oiE '(verified|confirmed|dispatched) against (real file )?`[^`]+`' || true)

while IFS= read -r CLAIM_PATH; do
  [ -z "$CLAIM_PATH" ] && continue
  if ceg_path_was_read "$CLAIM_PATH"; then
    continue
  fi
  if ! ceg_path_exists "$CLAIM_PATH"; then
    ceg_block "Verification claim cites missing path: ${CLAIM_PATH}" "No session Read breadcrumb and file not found on disk."
  fi
  ceg_block "Verification claim without session Read: ${CLAIM_PATH}" "Read the file via the Read tool before writing VERIFIED/Confirmed against this path."
done < <(printf '%s' "$VERIFY_PATHS" | sort -u)

# All explicit verification paths were read this session — allow the write.
if printf '%s' "$VERIFY_PATHS" | grep -qE '.+'; then
  exit 0
fi

# Assertion keywords — phrases that claim a verified/wired/done state.
# ALIGNED 2026-06-15 to the Go binary's assertionPatterns (internal/gate/patterns.go),
# which was softened by ADR 0064 (2026-06-13) after a 59-fire audit showed 58/59 fires were
# false positives — bare "confirmed"/"verified", the prose word "end-to-end", and Codex
# verdict labels (SHIP-WITH-HEDGES, 0H/2M/1L) appearing as ordinary words, not claims. The
# bash floor had NOT received that softening and so over-blocked relative to the binary — the
# exact binary/floor divergence the Grok cross-layer batch exists to eliminate. The dangerous
# bare form ("verified against `<path>`" without a Read) is still caught by the VERIFY_PATHS
# block above (verifiedPattern + reads-log check), mirroring gate.go. Keep ONLY claim-shaped
# forms; this list now matches patterns.go one-for-one.
PATTERNS='(\bis wired\b|\bis complete\b|\bis done\b|\bfully integrated\b|\bfully wired\b|\bthe data shows\b|\bdirectory contains only\b|\bcontains only\b|\bhas been (confirmed|verified)\b|\bis (confirmed|verified)\b|\bwas (confirmed|verified)\b|\bfunctionality is\b|\bhas a bug\b|\bthe bug is\b|\bbroken because\b|\bthe gate checks\b|\bthe function does\b)'

MATCH=$(echo "$TEXT" | grep -oiE "$PATTERNS" | head -3 | tr '\n' '|' | sed 's/|$//')

if [ -z "$MATCH" ]; then
  exit 0
fi

cat >&2 <<BLOCK
[gate4-BLOCK] Assertion language detected: "${MATCH}"
[gate4-BLOCK] Gate 4: before writing a claim like this, you must have a prior Read of the resource.
[gate4-BLOCK] Proxy evidence (filtered glob, SQL EXISTS, simulation, exit code) is not verification.
[gate4-BLOCK] Downgrade the language to match your evidence, or Read the artifact first.
[gate4-BLOCK] Source: AOF AGENT_FRAMEWORK.md §4 (Gate 4)
BLOCK

printf '%s\tclaim-evidence-gate\tBLOCKED: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$MATCH" >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true

exit 2