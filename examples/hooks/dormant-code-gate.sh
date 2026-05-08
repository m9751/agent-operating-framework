#!/usr/bin/env bash
# fail-mode: closed
# blast-radius: security
# =============================================================================
# dormant-code-gate.sh — CI / pre-merge meta-hook
#
# Backs scope-discipline Gate 5 (Dormant Code Check). Takes a list of
# code file paths as arguments and rejects any file whose extracted
# symbols have zero callers anywhere else in the repository.
#
# Why this hook exists:
#   The rule says "before proposing any remediation, grep for callers."
#   v1.4 left this as prose. This hook moves it to PR-time enforcement:
#   you cannot merge a refactor / audit / cosmetic-hygiene change to a
#   file that nothing else references.
#
# Contract (per ~/.claude/plans/indexed-greeting-unicorn.md Phase C.1):
#   - Python: extract `def name` / `class name` (capture group 2)
#   - TypeScript/JavaScript: extract `export ... name` (capture group 1)
#   - Shell: extract filename basename (without extension)
#   - Symbol min length: 6 chars (filters out 'init', 'main', etc.)
#   - Caller search: rg / grep across .py .ts .js .sh .yml .yaml .md .toml
#     excluding the source file itself
#   - Skip extensions: .md .yml .yaml .json .txt (not "code" in this sense)
#   - Soft pass: file with 0 extractable symbols passes with a note
#
# Hook type: CI check (NOT a Claude Code PreToolUse hook — different shape)
# Exit codes:
#   0 — all checked files have callers (or are non-code, or have no symbols)
#   1 — at least one file is fully orphan (every extracted symbol has 0 callers)
#   2 — usage error (no args)
#
# Usage:
#   bash examples/hooks/dormant-code-gate.sh <file.py> [<file.ts> ...]
# =============================================================================

set -euo pipefail

MIN_SYMBOL_LEN=6
SKIP_EXTENSIONS_RE='\.(md|yml|yaml|json|txt|lock|log)$'

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <code-file> [<code-file> ...]" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Symbol extractors
# ---------------------------------------------------------------------------

extract_python_symbols() {
  local file="$1"
  grep -oE '^(def|class)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)' "$file" 2>/dev/null \
    | awk '{print $2}' \
    | awk -v min="$MIN_SYMBOL_LEN" 'length($0) >= min' \
    | sort -u
}

extract_ts_js_symbols() {
  local file="$1"
  grep -oE '^export[[:space:]]+(default[[:space:]]+)?(function|class|const|interface|type|enum)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)' "$file" 2>/dev/null \
    | awk '{print $NF}' \
    | awk -v min="$MIN_SYMBOL_LEN" 'length($0) >= min' \
    | sort -u
}

extract_shell_symbols() {
  local file="$1"
  # Shell scripts are typically invoked by path. Use the basename.
  local base
  base="$(basename "$file" .sh)"
  if [[ ${#base} -ge $MIN_SYMBOL_LEN ]]; then
    echo "$base"
  fi
}

extract_symbols() {
  local file="$1"
  local lang_symbols=""
  case "$file" in
    *.py)        lang_symbols="$(extract_python_symbols "$file")" ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) lang_symbols="$(extract_ts_js_symbols "$file")" ;;
    *.sh|*.bash) lang_symbols="$(extract_shell_symbols "$file")" ;;
    *)           lang_symbols="" ;;
  esac

  # Always include the file's stem (basename without extension) — catches
  # path-style references in CI yaml, docs, shell invocations.
  local stem
  stem="$(basename "$file" | sed 's/\.[^.]*$//')"
  if [[ ${#stem} -ge $MIN_SYMBOL_LEN ]]; then
    if [ -n "$lang_symbols" ]; then
      printf '%s\n%s\n' "$lang_symbols" "$stem" | sort -u
    else
      echo "$stem"
    fi
  else
    echo "$lang_symbols"
  fi
}

# ---------------------------------------------------------------------------
# Caller search — grep the repo for the symbol, excluding the source file.
# ---------------------------------------------------------------------------

count_callers() {
  local symbol="$1"
  local source_file="$2"
  # Use word-boundary grep so 'do_thing' doesn't match 'do_thing_else'.
  # `|| true` on each grep so empty output (= no matches) doesn't trip
  # `set -o pipefail` and kill the loop.
  local raw filtered
  raw="$(grep -rn -w \
    --include='*.py' --include='*.ts' --include='*.tsx' \
    --include='*.js' --include='*.jsx' --include='*.mjs' --include='*.cjs' \
    --include='*.sh' --include='*.bash' \
    --include='*.yml' --include='*.yaml' \
    --include='*.md' --include='*.toml' \
    "$symbol" . 2>/dev/null || true)"
  filtered="$(echo "$raw" | grep -v "^\./${source_file#./}:" || true)"
  if [ -z "$filtered" ]; then
    echo "0"
  else
    echo "$filtered" | wc -l | tr -d ' '
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

failed=0
checked=0
notes=()

for file in "$@"; do
  if [ ! -f "$file" ]; then
    echo "::error file=$file::file not found" >&2
    failed=$((failed + 1))
    continue
  fi

  # Skip non-code extensions.
  if echo "$file" | grep -qE "$SKIP_EXTENSIONS_RE"; then
    notes+=("$file: skipped (non-code extension)")
    continue
  fi

  checked=$((checked + 1))

  # Extract symbols.
  symbols="$(extract_symbols "$file")"

  if [ -z "$symbols" ]; then
    notes+=("$file: 0 extractable symbols (soft pass — no symbols to check)")
    continue
  fi

  # For each symbol, count callers.
  symbol_count=$(echo "$symbols" | wc -l | tr -d ' ')
  orphan_count=0
  orphan_list=""

  while IFS= read -r symbol; do
    if [ -z "$symbol" ]; then
      continue
    fi
    callers="$(count_callers "$symbol" "$file")"
    if [ "$callers" -eq 0 ]; then
      orphan_count=$((orphan_count + 1))
      orphan_list="${orphan_list}    - ${symbol}"$'\n'
    fi
  done <<< "$symbols"

  # File is fully orphan only if EVERY symbol has 0 callers.
  if [ "$orphan_count" -eq "$symbol_count" ]; then
    failed=$((failed + 1))
    echo "::error file=$file::fully orphan — all $symbol_count extracted symbol(s) have 0 callers outside this file" >&2
    echo "$orphan_list" >&2
    echo "    Per scope-discipline Gate 5: 'ceremony must match blast radius.'" >&2
    echo "    Either find callers, downgrade to cosmetic code hygiene, or drop the change." >&2
  fi
done

# Print soft notes (skipped + no-symbol files).
for note in "${notes[@]:-}"; do
  [ -n "$note" ] && echo "$note"
done

if [ "$failed" -gt 0 ]; then
  echo "" >&2
  echo "dormant-code-gate: $failed of $checked code file(s) are fully orphan." >&2
  echo "See AGENT_FRAMEWORK.md §5.3 + scope-discipline.md Gate 5." >&2
  exit 1
fi

echo "dormant-code-gate: $checked code file(s) checked; all have callers (or no extractable symbols)."
exit 0
