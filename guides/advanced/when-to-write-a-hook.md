# When to Write a Hook

> A hook is a barrier, not a reminder. Write one only when the cost of the model ignoring the rule exceeds the cost of blocking it.

The AOF enforcement ladder is: **preference → rule → hook**. Most discipline lives in the rule layer. Hooks exist for the narrow set of cases where a rule alone is insufficient — where silent non-compliance has happened before or where the consequence of a miss is high enough to justify blocking.

---

## The Decision Test

Before writing a hook, answer three questions:

**1. Has the rule been violated with real consequence — OR is the hook advisory/telemetry?**
Blocking hooks (exit 2) are postmortem artifacts. Write one when you have evidence of the failure mode, not when you imagine it. The three-failure-stop-gate exists because of the 2026-05-15 kb_mcp_server saga (8 fix commits in 2 hours). The claim-evidence-gate exists because of the 2026-05-27 bloomberg-terminal fabrication incident.

If you have no postmortem and the hook would block, write the rule first.

**Exception — advisory and telemetry hooks (exit 0 always):** these do not require a postmortem. Hooks like `agentsmd-session-inject.sh` (context injection) and `aof-eval-opportunity-counter.sh` (telemetry) are proactive infrastructure. They never block, so the postmortem bar does not apply. The bar for advisory hooks is: will this emit useful signal or context without adding friction? If yes, build it. See "Hook Types by Blast Radius" below.

**2. Can the hook detect the violation mechanically?**
Hooks operate on structured tool payloads. They can parse JSON, match regex against command strings, check file existence, and read breadcrumb logs. They cannot reason about intent, understand context, or weigh tradeoffs.

If the only way to detect the violation requires understanding what the agent *meant*, the hook will false-positive constantly. Write the rule instead.

**2a. Is this already enforced by an existing hook or rule?**
Before writing, check `examples/hooks/README.md` for existing coverage. Hooks that overlap an existing gate create maintenance debt and can produce confusing double-block messages. If the behavior you want is almost covered by an existing hook, extend it rather than adding a new one.

**3. Is the blast radius acceptable?**
Every hook that exits 2 blocks the tool call. Every false positive is a friction tax on every session. Security and deploy hooks justify closed failure modes. Advisory patterns do not. If your hook would fire more than once per 100 tool calls in normal operation, it is miscalibrated.

---

## Hook Types by Blast Radius

| Type | Failure mode | When to use |
|------|-------------|-------------|
| **Security gate** | Fail-closed (exit 2) | Secrets in content, claim-without-read, infra mutations without guard |
| **Discipline gate** | Fail-closed (exit 2) | Three-failure stop, AGENTS.md not read before repo work |
| **Advisory hook** | Fail-open (exit 0) | Telemetry, context injection, breadcrumb recording |

Advisory hooks must log every fail-open path. See `silent-failure-discipline.md`.

---

## What Belongs in a Rule, Not a Hook

- Tone or communication style
- "Think before acting" reminders
- Anything that requires reading the model's reasoning, not its tool calls
- Patterns that fire legitimately in normal work (e.g., any use of the word "confirmed")
- Guidance that varies by context (hooks are context-blind)

---

## Hook Anatomy

Every hook in the AOF examples directory follows this structure:

```bash
#!/usr/bin/env bash
# <hook-name>.sh
# <event>: <matcher> — one-line description
# fail-mode: open|closed | blast-radius: <scope>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/breadcrumb-lib.sh" 2>/dev/null || true

INPUT=$(cat)  # or HOOK_INPUT_JSON

# Parse → gate logic → exit 0 (allow) or exit 2 (block)
```

Key invariants:
- **Stdin is the payload.** Never rely on env vars for the tool call data.
- **Exit 0 allows. Exit 2 blocks.** No other exit code has defined semantics.
- **Every fail-open path logs.** See `silent-failure-discipline.md`.
- **`set -euo pipefail` at the top.** Unhandled errors exit non-zero — which is exit 1, not exit 2. Because the harness may treat non-zero as a block, parse failures and dependency errors must be caught explicitly and exit 0 (fail-open) with a log line.

---

## Testing Before Shipping

A hook that passes an exit-code check is not verified. Verification requires observing the side effect:

1. **Block path:** construct a payload that should be blocked. Run the hook directly (`echo '<json>' | bash hook.sh`). Confirm exit 2 and the correct stderr message.
2. **Allow path:** construct a clean payload. Confirm exit 0 and no block message.
3. **Fail-open path:** pass empty stdin or malformed JSON. Confirm exit 0 and a log line in `.errors.log`.
4. **Live session:** register the hook in `settings.json`, open a session, trigger the gated action. Confirm the block fires in the session UI.

See `examples/hooks/README.md` for the per-hook test matrix.
