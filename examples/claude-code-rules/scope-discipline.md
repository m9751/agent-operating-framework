# Scope Discipline — MANDATORY

## The Rule
Fix only what was asked. Reuse what exists. Never add complexity, scope, or dependencies beyond the specific task. If you're about to build something from scratch, search first — it probably already exists.

## The Four Gates

**Gate 1 — Feature Freeze on Working Code.** Never add complexity (abstractions, security layers, helper classes, extra scopes) to code that is already functional. Fix ONLY the explicit bug or request. The test: "Is this change required to fix the bug the user reported?" If no — don't touch it.

**Gate 2 — Approved Stack Only.** Only use tools and libraries you've agreed on with your team. Before any new `import`, `require`, `pip install`, or `npm install`, ask: "Is this in our approved stack?" If no, pause and evaluate. Never add tools because "it's the standard," "more stars," or "feels cleaner."

**Gate 3 — Search Before Building.** Before creating code from scratch, search for existing implementations — package registries, internal libraries, templates, starter kits. Show the user what exists, itemize reuse vs net-new, THEN propose what to build. This applies to your own codebase too: check what you already have before writing new utilities.

**Gate 4 — Eat Your Own Cooking.** When building something that demonstrates a platform's capability, use that platform. No simulating it in a different language. No "Phase 1 in Language X, Phase 2 in the real platform." Phase 1 IS the real platform.

## The Test
If the answer to "why did you add this?" starts with "I thought it would be better..." or "everyone uses..." — this rule was skipped.

## Why
- Working OAuth flow broken for 5 hours after unrequested PKCE addition.
- Built 6 API resources from scratch while production-grade specs sat in the package registry unused.
- Demo delivered with zero apps running on the target platform (all in a different language).
- Repeated unapproved dependency additions creating maintenance debt the user inherits.

## Enforcement
Gates 2–3 can be enforced with `PreToolUse` hooks that block code generation unless a prior search was logged. See `examples/hooks/search-gate.sh` for a working example.
