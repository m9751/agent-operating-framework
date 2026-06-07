# Silent Failure Discipline

> Every fail-open path must write a log line. Silence is not success.

The AOF's enforcement architecture classifies hooks by blast radius: destructive and security hooks fail-closed; advisory hooks fail-open. This is correct. The failure is what happens next: an advisory hook that fails open silently is indistinguishable from an advisory hook that fired successfully.

A broken gate that logs nothing looks identical to a healthy gate that found nothing wrong.

---

## The Discipline

**Rule:** Any hook in `~/.claude/hooks/` that uses fail-open semantics — any code path that exits 0 without completing the hook's work (missing env var, malformed JSON, missing breadcrumb directory, parse error) — **must** write a tab-separated line to the central error log before exiting.

**Error log location:** `~/.claude/migration-breadcrumbs/.errors.log`

**Format:** one line per fail-open event, tab-separated:

```
<ISO_TIMESTAMP>\t<hook-name>\t<reason-slug>
```

Example:
```
2026-06-07T14:23:01Z	source-truth-write-gate	CLAUDE_SESSION_ID-unset-or-empty
2026-06-07T14:23:02Z	no-guess-gate	payload-parse-failed
```

---

## Implementation Pattern

In every fail-open return path, add this before `exit 0`:

```bash
printf '%s\t%s\t%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$(basename "$0" .sh)" \
  "short-reason-slug" \
  >> "${HOME}/.claude/migration-breadcrumbs/.errors.log" 2>/dev/null || true
```

Or, if your hook already sources `breadcrumb-lib.sh`, define a `bc_write_error` wrapper:

```bash
bc_write_error() {
  local reason="$1"
  local errors_log="${HOME:-$USERPROFILE}/.claude/migration-breadcrumbs/.errors.log"
  mkdir -p "$(dirname "$errors_log")" 2>/dev/null || true
  printf '%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(basename "${BASH_SOURCE[1]:-$0}" .sh)" \
    "$reason" \
    >> "$errors_log" 2>/dev/null || true
}
```

The final `|| true` ensures that even a failing write to the errors log does not crash the hook. The write is best-effort.

---

## Reason Slugs

Use a small, stable vocabulary of snake_case slugs. Reusing the same reason across hooks lets monitoring tools cluster identical failure modes:

| Slug | When to use |
|---|---|
| `CLAUDE_CODE_SESSION_ID-unset-or-empty` | Session key env var missing |
| `payload-parse-failed` | JSON stdin parse error |
| `breadcrumb-dir-missing` | Breadcrumb directory could not be created |
| `dependency-missing` | Required tool (python3, jq, git) not in PATH |
| `library-load-failed` | `source breadcrumb-lib.sh` failed |
| `settings-json-missing` | `~/.claude/settings.json` not found |
| `telemetry-env-vars-not-set` | AOF_TELEMETRY_URL or AOF_TELEMETRY_KEY unset |

---

## Self-Test

Before shipping any hook that has fail-open paths, verify the error log write:

```bash
# Force the fail-open path (e.g., unset the session ID)
unset CLAUDE_CODE_SESSION_ID

# Pipe a test payload to the hook
echo '{"prompt":"test"}' | bash ~/.claude/hooks/your-hook.sh

# Confirm a new line appeared in the errors log
tail -1 ~/.claude/migration-breadcrumbs/.errors.log
# Expected: <timestamp>\tyour-hook\t<reason-slug>
```

If `tail -1` does not show a new row, the hook is silent on failure — fix before deploying.

---

## The Watchdog

The error log feeds a session-close watchdog: a Stop hook that reads `.errors.log` for lines written during the current session and surfaces them as a summary. This converts invisible fail-opens into visible events — you see which hooks are degraded and why before the next session starts.

The watchdog is most useful when run for the first time: a fresh installation often produces a burst of `CLAUDE_CODE_SESSION_ID-unset-or-empty` entries that reveal hooks sourcing the wrong env var.

---

## Origin

A full governance audit of 63 hooks on 2026-06-07 found approximately 50 silent fail-open paths. `apply-migration-breadcrumb.sh` and `apply-migration-stop-warn.sh` had already implemented the error-log contract and produced 1,441 entries in `.errors.log` over the prior month. The remaining hooks had fail-open paths that exited 0 without logging — the watchdog could not detect them.

This discipline forces every fail-open path into the visible set. The watchdog can then report what it actually knows vs. what it is blind to.

---

## Related

- [`guides/hook-operations.md`](../hook-operations.md) — the three operational questions (failure, theater, escape)
- [`examples/hooks/breadcrumb-lib.sh`](../../examples/hooks/breadcrumb-lib.sh) — session-scoped breadcrumb API
- [`AGENT_FRAMEWORK.md` §5.2](../../AGENT_FRAMEWORK.md) — fail-mode taxonomy
- [`guides/advanced/hook-audit-methodology.md`](hook-audit-methodology.md) — 4-track audit pattern
