# Session Lifecycle — MANDATORY

## Session Open
Before doing any work:
1. Load persistent state (memory, open items, pending work)
2. Present the current state to the user as a numbered list
3. Ask what the focus is — do NOT assume or charge ahead
4. Do NOT start any task until the user confirms the focus

## Session Close
Before ending any session:
1. Diff promises vs. delivery — what was said vs. what got done
2. Log any gaps explicitly to the user
3. If a gap has appeared in a prior session, escalate it (memory → rule → hook)
4. Update persistent state with what changed

## Why This Exists
Sessions without explicit focus lead to wasted work, skipped checklists, and context drift. The 30 seconds of alignment at open saves hours of rework. The audit at close catches gaps before they compound.
