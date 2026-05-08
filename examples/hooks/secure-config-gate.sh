#!/usr/bin/env bash
# fail-mode: closed
# blast-radius: security
# =============================================================================
# secure-config-gate.sh — PreToolUse hook
#
# Backs the secure-configuration rule. Two checks combined:
#
#   1. Secret-pattern detection (all tools)
#      Scans tool input JSON for known secret shapes (provider tokens,
#      JWTs, private key headers, keyword-paired credentials). If any
#      pattern matches, blocks with exit 2.
#
#   2. Protected-path detection (Write tool only)
#      Blocks Write to paths inside ~/.m2/settings.xml, ~/.ssh/,
#      ~/.aws/credentials, .env files, service-account*.json, ~/.kube/config.
#      These files are operator-owned and must be edited via targeted
#      Edit + backup, not whole-file Write.
#
# Configuration:
#   AOF_SECRET_PATTERNS_FILE — optional path to a file containing additional
#     extended-regex patterns (one per line). Appended to the built-in
#     SECRET_REGEX at runtime.
#
# Hook type: PreToolUse
# Exit codes:
#   0 — allow (no secret pattern detected; not a Write to a protected path)
#   2 — block (secret pattern detected OR Write target is protected)
#
# Usage (CI self-test):
#   echo '{"tool_name":"...","tool_input":{...}}' | bash examples/hooks/secure-config-gate.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Built-in secret-pattern regex (extended POSIX). Each pipe-separated branch
# is a known credential shape. Order: more-specific first.
# ---------------------------------------------------------------------------

SECRET_REGEX='sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]+|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]+PRIVATE KEY-----|(api[_-]?key|secret_key|password|bearer)[[:space:]]*[=:][[:space:]]*[A-Za-z0-9._/+=-]{16,}'

# Optionally extend with org-specific patterns from a file.
if [[ -n "${AOF_SECRET_PATTERNS_FILE:-}" && -f "$AOF_SECRET_PATTERNS_FILE" ]]; then
  while IFS= read -r extra; do
    [[ -z "$extra" || "$extra" == \#* ]] && continue
    SECRET_REGEX="${SECRET_REGEX}|${extra}"
  done < "$AOF_SECRET_PATTERNS_FILE"
fi

# ---------------------------------------------------------------------------
# Read tool input from stdin.
# ---------------------------------------------------------------------------

INPUT="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  # Fallback: treat raw stdin as the corpus to scan.
  CORPUS="$INPUT"
  TOOL_NAME=""
else
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
  CORPUS="$(echo "$INPUT" | jq -r '.tool_input | tostring')"
fi

# ---------------------------------------------------------------------------
# Check 1: secret-pattern detection (applies to ALL tools)
# ---------------------------------------------------------------------------

check_secrets() {
  if echo "$CORPUS" | grep -qiE "$SECRET_REGEX"; then
    matched="$(echo "$CORPUS" | grep -oiE "$SECRET_REGEX" | head -1)"
    # Redact the actual value in the error message.
    redacted="$(echo "$matched" | sed -E 's/[A-Za-z0-9._/+=-]{8,}/[REDACTED]/g')"
    echo "::error::secure-config-gate: secret pattern detected in tool input ($redacted)" >&2
    echo "Move the secret to env var / keychain / vault and reference by name." >&2
    return 2
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Check 2: protected-path detection (Write tool only)
# ---------------------------------------------------------------------------

PROTECTED_PATH_REGEX='\.m2/settings\.xml|\.ssh/(id_|config$|known_hosts$)|\.aws/(credentials|config)$|(^|/)\.env(\.[A-Za-z]+)?$|service-account.*\.json|\.kube/config$'

check_protected_paths() {
  if [[ "$TOOL_NAME" != "Write" ]]; then
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  local fp
  fp="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
  if [[ -z "$fp" ]]; then
    return 0
  fi

  if echo "$fp" | grep -qE "$PROTECTED_PATH_REGEX"; then
    echo "::error::secure-config-gate: Write blocked on protected path: $fp" >&2
    echo "Use Edit with a backup (cp \$file \$file.bak) for shared config files." >&2
    return 2
  fi
  return 0
}

if ! check_secrets; then
  exit 2
fi

if ! check_protected_paths; then
  exit 2
fi

exit 0
