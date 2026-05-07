#!/usr/bin/env bash
# fail-mode: closed
# blast-radius: security
# =============================================================================
# empty-rule-body-gate.sh — CI / pre-merge meta-hook
#
# Rejects rule files (examples/claude-code-rules/*.md) that fail the
# "is this actually a rule, or is it a stub" contract:
#
#   1. Body byte count >= 200 (rule has substantive body, not a placeholder)
#   2. File contains a "## Why" section (rule is incident-driven, not aspirational)
#
# The two conditions together prevent the failure mode where a rule file
# exists with a heading and frontmatter but no actual rule content — the
# class of false-positive that motivated this hook (rules marked "applied"
# by automated detectors when only the file existed).
#
# Why these specific checks:
#   - Byte count catches stubs and abandoned drafts
#   - "## Why" presence catches aspirational rules that don't reference an
#     incident — the framework's hard line is "rules are born from incidents,
#     not best-practice lists"
#
# Why not "## The Rule" specifically:
#   - The framework allows multiple rule shapes (declarative rule, decision
#     framework, anti-pattern). Requiring a single section name would
#     false-positive on legitimate variants (no-local-infrastructure uses
#     "## The Question" because it's a decision framework, not a rule).
#
# Hook type: CI check (runs in rules-lint.yml workflow)
# Exit codes:
#   0 — all passed file paths satisfy the contract
#   1 — one or more files failed the contract; per-file reasons printed
#   2 — usage error or unreadable file
#
# Usage:
#   bash examples/hooks/empty-rule-body-gate.sh <file.md> [<file.md> ...]
# =============================================================================

set -euo pipefail

MIN_BYTES=200

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <rule-file.md> [<rule-file.md> ...]" >&2
  exit 2
fi

failed=0
checked=0

for path in "$@"; do
  if [ ! -f "$path" ]; then
    echo "::error file=$path::file not found" >&2
    failed=$((failed + 1))
    continue
  fi

  checked=$((checked + 1))
  bytes=$(wc -c < "$path" | tr -d ' ')
  has_why=$(grep -cE "^## Why" "$path" || true)

  reasons=()

  if [ "$bytes" -lt "$MIN_BYTES" ]; then
    reasons+=("body too small: $bytes bytes < $MIN_BYTES required")
  fi

  if [ "$has_why" -eq 0 ]; then
    reasons+=("missing '## Why' section — rules must reference the incident that produced them")
  fi

  if [ "${#reasons[@]}" -gt 0 ]; then
    failed=$((failed + 1))
    for reason in "${reasons[@]}"; do
      echo "::error file=$path::$reason" >&2
    done
  fi
done

if [ "$failed" -gt 0 ]; then
  echo "" >&2
  echo "empty-rule-body-gate: $failed of $checked file(s) failed the contract" >&2
  echo "See AGENT_FRAMEWORK.md §5.3 for the rule-to-hook coverage matrix." >&2
  exit 1
fi

echo "empty-rule-body-gate: $checked file(s) passed (>= $MIN_BYTES bytes + ## Why section)"
exit 0
