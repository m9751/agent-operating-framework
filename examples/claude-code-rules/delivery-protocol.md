# Delivery Protocol — MANDATORY

## The Rule
Every deliverable follows ONE workflow: **Build → Store → Deploy → Remember → Log**. No inventing new workflows. No ad-hoc paths.

## The Five Steps

**1. Build.** Create locally. Test it. Get the user's approval before deploying.

**2. Store.** Save the source to a durable location (cloud storage, repo) — not just the local filesystem.

**3. Deploy — route by audience:**
- **Customer-facing** → deploy with access control + analytics
- **Public content** → deploy to a public hosting platform (GitHub Pages, etc.)
- **Internal-only** → either, but prefer the option with better observability
- **Never** deploy customer-specific content to public URLs. **Never** deliver as a file download.

**4. Remember.** Update your project's knowledge base with what was delivered, the live URL, and key context. The goal: any future session can find this deliverable without asking.

**5. Log.** After ANY deliverable: record it in your tracking system (database, project board, etc.). Verify the URL returns 200. If it has analytics, verify the tracking works end-to-end — not just that the tracking pixel loaded.

## HTML Builds — Token Hygiene
When building or editing HTML deliverables: output only the changed section/component, use Edit (not full rewrites) for partial changes, don't re-emit unchanged CSS/JS during iteration. Full-document rewrites on each iteration waste 60-80% of output tokens on unchanged content.

## Post-Delivery Checklist
Before telling the user something is done:
1. Did you log it?
2. Did you verify the URL?
3. If it has tracking, did you verify events actually appear (not just that the pixel returns 200)?
4. If it's account-specific, did you store it in the account's artifact history?

## Why
- Deliverables scattered across downloads, local folders, multiple cloud services — sessions invented different workflows each time.
- Post-delivery checklist skipped 10+ times across sessions. The user caught it every time.
- HTML iterations burned most output tokens re-emitting unchanged content.

## Enforcement
Step 5 can be enforced with a `PreToolUse` hook that tracks whether a logging INSERT was made before the agent claims completion. See `examples/hooks/delivery-gate.sh` for a working example.
