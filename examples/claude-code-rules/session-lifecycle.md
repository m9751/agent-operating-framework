# Session Lifecycle — MANDATORY

## The Rule
Every session has three phases — **Open**, **Execute**, **Close**. Each has non-negotiable steps. Skipping any of them reproduces the failures this rule was born from.

## Phase 1 — Open
1. **Read persistent state** (memory files, open items, pending work). Present as a numbered list.
2. **Ask the user what the focus is.** Do NOT start any task until they confirm. Sessions without explicit focus produce drift and wasted work — 30 seconds of alignment saves hours of rework.
3. **Emit a scope anchor.** After the user confirms focus, output one italic line before any tool use: *Session focus: [confirmed scope in one sentence].* This is a commitment artifact — it closes the scope and signals readiness to execute.

## Phase 2 — Execute

**Plan Mode exit.** When the user says "execute," "go," "do it," or any variant meaning start executing:
1. **Exit Plan Mode first** — before any Edit/Write/Bash/tool call.
2. Wait for Plan Mode to actually exit.
3. THEN begin execution using the protocol below.

**Per-step execution protocol:** fact-check → read → write → dry run → result check. Do NOT proceed to the next step until the current step's result check passes.

**NEVER:** start executing while in Plan Mode; batch multiple plan steps without verifying each; skip the dry run because "it's simple."

## Phase 3 — Close
When the user says "done," "wrap up," or the conversation naturally concludes:

1. **Diff promises vs delivery against testable Done Criteria.** What was said, what shipped, what's the gap?
   **Pre-condition:** every plan or handoff that opens a multi-step build MUST include a `## Done Criteria` section before the build starts — a numbered list of testable, observable conditions written against the schema in [`guides/advanced/done-criteria-schema.md`](../../guides/advanced/done-criteria-schema.md). Phase 3's diff walks each criterion explicitly: ✅ met / ❌ unmet (with evidence) / ⚠️ partial (with gap). Prose-shaped "we did the work" is NOT a substitute. **Enforcement:** [`scripts/validate-done-criteria.py`](../../scripts/validate-done-criteria.py) runs in CI on every plan file added or modified in a PR; prose-only Done Criteria fail the schema check at PR time. The validator is the control; this rule is supporting documentation.
2. **Log gaps explicitly** to the user. Repeated gap → **escalate**: write a new rule, OR add a hook gate. The same escalation applies to rule files themselves — empty-bodied rules masquerading as enforcement are a known failure (see [`examples/hooks/empty-rule-body-gate.sh`](../hooks/empty-rule-body-gate.sh)).
3. **Verify post-delivery checklist** ran for every deliverable this session.
4. **Update persistent state.** Add/remove pending items based on what happened.
5. **Generate handoff note** covering files modified, deployments, blockers, open items, errors.
6. **Run `/doctor` weekly** (or equivalent health check). Review: orphan plugin references, path-escape errors, missing configurations, MCP server failures. Fix in the same session — they silently compound as invisible token tax across hundreds of sessions. **Positive verification:** when the run is clean, log `doctor-clean YYYY-MM-DD` to the handoff note's errors section. Absence of errors is not the same as verified-clean; the log entry IS the verification.

## The Principle
**Memory files are advice. Rules are law. Hooks are barriers.** If advice gets ignored twice, it becomes a rule. If a rule gets ignored, it becomes a hook. v1.4 lives this principle directly: Phase 3 Step 1 ships with a CI-enforced schema validator because rule prose alone has been shown insufficient against the failure mode it targets.

## Why
- Sessions without explicit focus → drift and wasted work.
- Executing without exiting Plan Mode → blocked-tool loops.
- Post-session audits caught repeated gaps that would otherwise compound.
- **2026-04** — Persistent memory file overflowed the agent's auto-load window. Critical context was invisible every session for weeks. Memory hygiene check at Phase 3 Step 4 is the response.
- **2026-04** — Weekly health check surfaced stale plugin references silently injecting unwanted descriptions. Phase 3 Step 6 is the response.
- **2026-04** — A pattern of rules marked "applied" with empty bodies surfaced. Proxy verification (file exists) had substituted for content verification (body has substance). Response is two automated gates: a Done Criteria schema validator (closes the prose-claim loophole) + an empty-rule-body hook (closes the empty-stub loophole). Rule alone was insufficient — automation IS the fix.
