# Session Lifecycle — MANDATORY

## The Rule
Every session has three phases — **Open**, **Execute**, **Close**. Each has non-negotiable steps. Skipping any of them reproduces the failures this rule was born from.

## Phase 1 — Open
1. **Read persistent state** (memory files, open items, pending work). Present as a numbered list.
2. **Ask the user what the focus is.** Do NOT start any task until they confirm. Sessions without explicit focus produce drift and wasted work — 30 seconds of alignment saves hours of rework.

## Phase 2 — Execute

**Plan Mode exit.** When the user says "execute," "go," "do it," or any variant meaning start executing:
1. **Exit Plan Mode first** — before any Edit/Write/Bash/tool call.
2. Wait for Plan Mode to actually exit.
3. THEN begin execution using the protocol below.

**Per-step execution protocol:** fact-check → read → write → dry run → result check. Do NOT proceed to the next step until the current step's result check passes.

**NEVER:** start executing while in Plan Mode; batch multiple plan steps without verifying each; skip the dry run because "it's simple."

## Phase 3 — Close
When the user says "done," "wrap up," or the conversation naturally concludes:

1. **Diff promises vs delivery.** What was said, what shipped, what's the gap?
2. **Log gaps explicitly** to the user. Repeated gap → **escalate**: write a new rule, OR add a hook gate.
3. **Verify post-delivery checklist** ran for every deliverable this session.
4. **Update persistent state.** Add/remove pending items based on what happened.
5. **Generate handoff note** covering files modified, deployments, blockers, open items, errors.
6. **Run `/doctor` weekly** (or equivalent health check). Review: orphan plugin references, path-escape errors, missing configurations, MCP server failures. Fix in the same session — they silently compound as invisible token tax across hundreds of sessions.

## The Principle
**Memory files are advice. Rules are law. Hooks are barriers.** If advice gets ignored twice, it becomes a rule. If a rule gets ignored, it becomes a hook.

## Why
- Sessions without explicit focus → drift and wasted work.
- Executing without exiting Plan Mode → blocked-tool loops.
- Post-session audits caught repeated gaps that would otherwise compound.
