# Hook Operations Guide

> The three questions most teams don't ask until something breaks.

Hooks are the strongest enforcement tier in the AOF — they intercept tool calls before the agent acts. But shipping hooks is not the same as operating hooks. This guide covers the operational layer: what happens when hooks fail, how to tell if they're working, and how to escape when one goes rogue.

---

## The Three Questions

### 1. What happens when a hook itself fails?

If a hook crashes mid-execution — `python3` not found, disk full, corrupt stdin, missing dependency — behavior is undefined unless you've declared it explicitly.

Some hooks fail-open silently (exit 0 without doing their work). Some exit with a non-2 code that the Claude Code runtime interprets as "allow." In either case, a broken gate is visually indistinguishable from a passing gate. You have no monitoring on hook health by default.

**The fix:** Every hook must declare its behavior on unexpected errors in its `# fail-mode:` header annotation. The three tiers:

| Annotation | Meaning | Use for |
|---|---|---|
| `# fail-mode: closed` | Block the tool call when the hook errors unexpectedly | Destructive or security-critical hooks |
| `# fail-mode: open` | Allow the tool call when the hook errors (advisory hooks) | Logging, habit-shaping, breadcrumb writers |
| `# fail-mode: silent-skip` | Accept and log a specific runtime condition without blocking | Watcher-class hooks that detect a known-non-error state (e.g., push skipped due to branch protection) |

A hook without a `# fail-mode:` annotation is rejected by the AOF's CI (`rules-lint.yml`).

For fail-closed hooks, the correct exit behavior on unexpected errors is to output a human-readable message to stdout and `exit 2` — the same exit code used for intentional blocks. This ensures the agent always sees a reason, never a silent allow.

---

### 2. Are these hooks actually changing behavior, or are they theater?

Without telemetry, you cannot distinguish "the gate is working" from "nothing bad happened to test it."

After 2 weeks of deployment, you should be able to answer:
- Which hooks fired this week?
- How many times did each hook block vs. allow?
- Was `SAFE_MODE` ever used?

If you can't answer those questions, your hooks are theater — they may be working, but you have no evidence either way.

**The fix:** instrument sessions with a Stop hook that reads breadcrumb files left by your blocking hooks and writes a summary row to a telemetry store. The pattern:

1. Each blocking hook writes a breadcrumb on fire (`bc_write "<hook>-fire"`) and on block (`bc_write "<hook>-block"`).
2. A Stop hook (`hook-telemetry-stop.sh`) runs at session end, counts fires and blocks per hook, and INSERTs one row per hook into a telemetry table.
3. Query the table weekly. Hooks with zero fires across many sessions are candidates for removal or scope review.

See `breadcrumb-lib.sh` in `examples/hooks/` for the breadcrumb API. A sanitized reference implementation of the telemetry Stop hook is the reference pattern; adapt it to your own telemetry store.

**Canonical incident:** A watcher hook was logging `PUSH-FAIL` approximately every 30 seconds for 14 days because branch protection on `main` required a PR. With telemetry on the watcher, this would have surfaced on day 1. Without it, it was discovered only during a separate audit. (AOF Incident #35.)

---

### 3. What is the exit strategy if a hook goes rogue?

V1.5 shipped no fast-disable path. If a blocking hook develops a bug that prevents all work — wrong pattern match, broken dependency, misconfigured path — the only recovery was editing `settings.json` to remove the hook registration, which could take minutes of confusion under pressure.

**The fix:** the `CLAUDE_HOOKS_SAFE_MODE` bypass pattern.

Every blocking hook checks for `CLAUDE_HOOKS_SAFE_MODE=1` at the top and exits 0 if it's set. To disable all blocking hooks for the current session:

```bash
export CLAUDE_HOOKS_SAFE_MODE=1
```

Recovery time: ~30 seconds. The env var is session-scoped — it does not persist across sessions or affect other terminal windows.

Add this check to every blocking hook immediately after the shebang and annotations:

```bash
# Emergency bypass — set CLAUDE_HOOKS_SAFE_MODE=1 to disable all blocking hooks.
if [[ "${CLAUDE_HOOKS_SAFE_MODE:-0}" == "1" ]]; then
  exit 0
fi
```

Advisory (fail-open) hooks do not need the bypass — they can't block work by definition.

---

## The Breadcrumb Protocol

Most AOF blocking hooks use a breadcrumb pattern to share session state between hook invocations. The `breadcrumb-lib.sh` library provides a simple file-based API:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/breadcrumb-lib.sh" 2>/dev/null || true

# Write a breadcrumb (named flag for this session)
bc_write "exchange-search-done"

# Check if a breadcrumb exists
if bc_exists "exchange-search-done"; then
  echo "already done this session"
fi

# Read a breadcrumb's value
target=$(bc_read "target-resource")
```

**Storage model:** one file per named breadcrumb at `$(bc_dir)/<session_key>-<name>`. The session key comes from `CLAUDE_CODE_SESSION_ID` (set by the Claude Code runtime). Breadcrumb files persist for the OS session — they do not auto-clear between Claude Code sessions unless `bc_dir` is cleaned.

**Cross-subprocess stability:** `bc_session_key()` must return the same value from any subprocess spawned within a Claude Code session. `CLAUDE_CODE_SESSION_ID` satisfies this; `$$` (shell PID) does not. Always prefer the env var.

---

## The `PUSH-SKIPPED` Pattern

Watcher-class hooks (FileSystemWatcher daemons, inotify cron) that auto-push to a protected branch will fail-loop indefinitely on GitHub `GH006: Protected branch update failed`. The correct pattern:

1. Keep the auto-commit step — useful as automatic local backup even when push is blocked.
2. Skip the auto-push step when branch protection is detected.
3. Log `PUSH-SKIPPED branch-protection-active` for auditability.
4. Document the operator's manual PR step as the surfacing path.

This is a `# fail-mode: silent-skip` hook — it detected a runtime condition that requires operator attention but does not indicate hook failure.

---

## Related

- [`examples/hooks/breadcrumb-lib.sh`](../examples/hooks/breadcrumb-lib.sh) — breadcrumb library
- [`examples/hooks/README.md`](../examples/hooks/README.md) — hook inventory and customization checklist
- [`guides/advanced/hook-audit-methodology.md`](advanced/hook-audit-methodology.md) — how to audit an existing hook installation
- [`AGENT_FRAMEWORK.md` §5.2](../AGENT_FRAMEWORK.md) — fail-mode taxonomy
- [`AGENT_FRAMEWORK.md` §5.3](../AGENT_FRAMEWORK.md) — rule-to-hook coverage matrix
