# Hook Audit Methodology

> How to audit an existing hook installation and know whether your hooks are actually working.

This guide describes a 4-track audit pattern for systematically reviewing all registered hooks in a Claude Code installation. Run it after a large hook deployment, before a major framework upgrade, or whenever you suspect a hook has gone silent.

---

## When to Run an Audit

- After deploying 5+ hooks for the first time
- After a machine migration or OS upgrade
- After any change to `settings.json` hook registrations
- When telemetry shows a hook with zero fires across many sessions (potential silent failure)
- Before tagging a new framework version

---

## The 4-Track Audit

### Track 1 — Registration Inventory

**Goal:** confirm that every hook in `settings.json` points to a file that exists.

```bash
# List all registered hooks from settings.json
jq '.hooks[] | .hooks[]? | .command // empty' ~/.claude/settings.json 2>/dev/null \
  | sort -u

# For each path, verify the file exists and is executable
jq -r '.hooks[] | .hooks[]? | .command // empty' ~/.claude/settings.json 2>/dev/null \
  | while read -r hook_cmd; do
      script=$(echo "$hook_cmd" | awk '{print $1}')
      if [[ -x "$script" ]]; then
        echo "OK   $script"
      else
        echo "FAIL $script (missing or not executable)"
      fi
    done
```

**Expected output:** every registered hook shows `OK`. Any `FAIL` line is a silent failure — the hook is registered but never runs.

---

### Track 2 — Annotation Compliance

**Goal:** confirm every hook file has the required `# fail-mode:` and `# blast-radius:` header annotations.

```bash
HOOKS_DIR="examples/hooks"  # adjust to your installation path

for f in "$HOOKS_DIR"/*.sh; do
  [[ "$f" == *breadcrumb-lib.sh ]] && continue  # library, not a hook
  fm=$(grep -m1 '# fail-mode:' "$f" | sed 's/.*fail-mode: //')
  br=$(grep -m1 '# blast-radius:' "$f" | sed 's/.*blast-radius: //')
  if [[ -z "$fm" || -z "$br" ]]; then
    echo "MISSING  $f  fail-mode='$fm' blast-radius='$br'"
  else
    echo "OK       $f  [$fm / $br]"
  fi
done
```

**Expected output:** every hook shows `OK` with both fields populated. Any `MISSING` line is a CI failure — `rules-lint.yml` would have caught this at PR time.

---

### Track 3 — Live Fire Test

**Goal:** verify each hook actually fires and returns the expected exit code when given a synthetic input.

The test shape is the same for every `PreToolUse` hook:

```bash
# Synthetic input: a tool call that the hook should allow (expect exit 0)
echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.txt","old_string":"a","new_string":"b"}}' \
  | bash examples/hooks/your-hook.sh
echo "Exit: $?"

# Synthetic input: a tool call that the hook should block (expect exit 2)
echo '{"tool_name":"Write","tool_input":{"file_path":"~/.m2/settings.xml","content":"x"}}' \
  | bash examples/hooks/secure-config-gate.sh
echo "Exit: $?"
```

For `UserPromptSubmit` hooks:

```bash
echo '{"prompt":"fix the build"}' | bash examples/hooks/focus-breadcrumb.sh
echo "Exit: $?"
```

**The stdin requirement:** always pipe a real JSON event. Running `bash -x hook.sh` without stdin produces the same empty-variable trace as a true silent failure (stdin not connected → `INPUT=` empty → early exit 0). The trace proves nothing without real stdin. (AOF rule: `read-before-acting.md` Gate 5.)

**Expected output:** allow paths exit 0, block paths exit 2, and the hook produces a human-readable message on block.

---

### Track 4 — Telemetry Validation

**Goal:** confirm that hooks are writing breadcrumbs during sessions and that the telemetry Stop hook is reading them correctly.

```bash
# After a session where you ran several tool calls:
ls /tmp/claude-hooks-${USER}/  # list breadcrumb files

# Expect files like:
#   <session_key>-no-guess-gate-fire
#   <session_key>-exchange-first-gate-fire
#   <session_key>-exchange-first-gate-block

# If the directory is empty after a session with many tool calls,
# either no hooks fired or bc_write is not being called.
```

If you have a telemetry Stop hook wired, query your telemetry store after a session:

```sql
SELECT hook_name, fire_count, block_count, session_date
FROM telemetry.hook_events
WHERE session_date = CURRENT_DATE
ORDER BY hook_name;
```

A hook with `fire_count = 0` across many sessions is a candidate for investigation:
- Is the hook registered in `settings.json`? (Track 1)
- Does the hook's pattern match the tool calls actually being made?
- Is the hook exiting early on a fail-open path without writing a breadcrumb?

---

## Triage Table

Use this table to record findings during an audit. One row per hook.

| Hook | Registration | Annotations | Live fire | Telemetry | Status | Notes |
|---|---|---|---|---|---|---|
| `read-gate.sh` | ✅ | ✅ | ✅ | ✅ | OK | |
| `secure-config-gate.sh` | ✅ | ✅ | ✅ | — | OK | telemetry not wired |
| `my-custom-gate.sh` | ❌ | ✅ | — | — | FAIL | path mismatch in settings.json |

**Status values:**
- `OK` — all checked tracks pass
- `WARN` — minor gap (e.g., telemetry not yet wired); hook is functional
- `FAIL` — hook is registered but not running, or running with wrong behavior

---

## Batch Audit Pattern (Codex)

For large installations (15+ hooks), running Track 2 + Track 3 manually is slow. You can dispatch a batch audit to a read-only Codex agent:

1. Collect all hook files into a single context block (one file per section).
2. Dispatch with the prompt: "For each hook file, check: (a) fail-mode and blast-radius annotations present, (b) exit 0 and exit 2 paths are reachable, (c) stdin is consumed before any logic that depends on it. Report findings as PASS/WARN/FAIL with file:line citations."
3. Triage the findings using the table above.

Codex cannot run the hooks — Track 3 (live fire) must always be done in a real shell with real stdin.

---

## Canonical Incidents

- **Incident #34** — a breadcrumb library used an undocumented env var as its primary session key. The var was set on Mac but empty on Win11, causing all source-truth-write gates to silently reject writes on Win11 for 14 days. Track 1 (registration) and Track 2 (annotations) both passed. Track 3 (live fire on Win11) would have caught it on day 1.
- **Incident #35** — a watcher hook auto-pushed to a branch-protected repo and logged `PUSH-FAIL` every 30 seconds for 14 days. Track 4 (telemetry) would have surfaced this on day 1.

---

## Related

- [`guides/hook-operations.md`](../hook-operations.md) — the three operational questions (failure, theater, escape)
- [`examples/hooks/breadcrumb-lib.sh`](../../examples/hooks/breadcrumb-lib.sh) — breadcrumb library
- [`AGENT_FRAMEWORK.md` §5.2](../../AGENT_FRAMEWORK.md) — fail-mode taxonomy
