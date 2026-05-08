# Changelog

All notable changes to this framework follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

---

## [1.5] — 2026-05

### Added
- **`examples/hooks/secure-config-gate.sh`** — combined PreToolUse hook backing the `secure-configuration` rule. Two checks: secret-pattern detection (provider tokens, JWTs, private-key headers, keyword-paired credentials) on all tools; protected-path detection (`~/.m2/settings.xml`, `~/.ssh/`, `~/.aws/credentials`, `.env*`, `service-account*.json`, `~/.kube/config`) on Write only. Configurable via `AOF_SECRET_PATTERNS_FILE`. Annotations: `# fail-mode: closed`, `# blast-radius: security`.
- **`examples/hooks/focus-breadcrumb.sh`** — UserPromptSubmit hook. Detects explicit-task patterns (named verb + target token) and writes a session breadcrumb consumed by `focus-confirmation-gate.sh`. Annotations: `# fail-mode: open`, `# blast-radius: advisory`.
- **`examples/hooks/focus-confirmation-gate.sh`** — PreToolUse advisory gate backing `session-lifecycle` Phase 1. Fires only on Edit/Write/Bash; warns when no breadcrumb exists this session. Read/Grep/Glob exempt. Always exit 0 — §1.3 precedence rejects hard-blocking the first action. Annotations: `# fail-mode: open`, `# blast-radius: advisory`.
- **`examples/hooks/dormant-code-gate.sh`** — CI lint backing `scope-discipline` Gate 5. Extracts symbols by language (Python `def`/`class`, TS/JS `export`, shell basename) plus the file's basename-without-extension, then greps the repo excluding the source file. Rejects PRs that modify code files where every extracted symbol has zero outside-callers. Annotations: `# fail-mode: closed`, `# blast-radius: security`.
- **3 new rules-lint.yml self-test steps** — synthetic positive + negative for each new hook on every PR.
- **3 new sanitized incidents** in `INCIDENTS.md` (#31, #32, #33).

### Changed
- **`AGENT_FRAMEWORK.md` §5.3 matrix** — `scope-discipline` row gains `dormant-code-gate.sh` for Gate 5; `session-lifecycle` row gains the focus-confirmation pair; `secure-configuration` row gains `secure-config-gate.sh`. Coverage moves from 3-of-6 enforced (v1.4) to **5-of-6 enforced** (v1.5). `no-local-infrastructure` remains advisory by design (decision framework, not hookable).
- **`AGENT_FRAMEWORK.md` §5.3 narrative** — drops "tracked for v1.5" gap framing. New prose explicitly distinguishes "advisory by design" from "advisory by gap" — only `no-local-infrastructure` is left in the former category.
- **`examples/hooks/README.md`** — 4 new inventory rows (secure-config-gate, focus-breadcrumb, focus-confirmation-gate, dormant-code-gate); new "The Focus-Confirmation Pair" section explaining the two-event pattern; 4 new customization checklist entries.
- `AGENT_FRAMEWORK.md` version bumped to v1.5.

---

## [1.4] — 2026-05

### Added
- **`.github/workflows/doc-link-check.yml`** — CI link-checker (lychee) on every PR + push to main. Catches broken internal/external doc links before merge.
- **`.github/workflows/rules-lint.yml`** — CI rules + plans linter. Enforces hook fail-mode + blast-radius annotations, runs Done Criteria schema validator, runs empty-rule-body gate.
- **`AGENT_FRAMEWORK.md` §5.3 Rule-to-Hook Coverage** — 6-row matrix mapping each rule to its hook (or marking it advisory). Honest 3-of-6 enforced ratio. Existing §5.3 (Rule Consolidation) renumbered §5.4.
- **`AGENT_FRAMEWORK.md` §5.2 fail-mode taxonomy** — destructive / security / advisory blast-radius classification with rationale per tier.
- **`AGENT_FRAMEWORK.md` §1.3 precedence rule** — explicit precedence over §0.5 Step 3, with 3 worked examples (bug report → fix; follow-up → do; ambiguous → ask).
- **`AGENT_FRAMEWORK.md` §0.5 Phase 1 Step 4** — italic scope-anchor commitment artifact emitted between focus confirmation and first tool use.
- **`AGENT_FRAMEWORK.md` §0.5 Phase 3 Step 1** — Done Criteria pre-condition referencing `done-criteria-schema.md` + the validator.
- **`AGENT_FRAMEWORK.md` §0.5 Phase 3 Step 5** — `doctor-clean YYYY-MM-DD` positive verification log entry.
- **`scripts/validate-done-criteria.py`** + **`scripts/fixtures/{good,bad}-plan.md`** — Python validator that enforces the Done Criteria schema in CI. Tested on 3 inputs; all match expected outcomes.
- **`guides/advanced/done-criteria-schema.md`** — schema spec with verb whitelist (9 verbs), good/bad examples, validator behavior.
- **`examples/hooks/empty-rule-body-gate.sh`** — CI meta-hook that rejects rule files < 200 bytes or missing `## Why` sections (closes the empty-stub loophole).
- 7 new sanitized incidents in `INCIDENTS.md` (#24–#30).
- Hook header annotations (`# fail-mode:`, `# blast-radius:`) on all 4 shipped hooks.

### Changed
- **`README.md`** — dropped "rules that can't be ignored" over-claim; replaced with "rules with documented enforcement contracts (some advisory by design)" + deep-link to coverage matrix.
- **`examples/claude-code-rules/no-local-infrastructure.md`** — full rewrite from categorical "MANDATORY ban on local persistence" to decision framework keyed to durability / recovery / trust boundary / operator availability. Filename retained for link stability; title now "Persistence Hosting — Decision Framework."
- **`examples/claude-code-rules/session-lifecycle.md`** — Phase 1 Step 3 (italic scope anchor), Phase 3 Step 1 (Done Criteria pre-condition with schema reference), Phase 3 Step 6 (positive verification). New Why entries reference incidents #24 + #25.
- `AGENT_FRAMEWORK.md` version bumped to v1.4.

---

## [1.3.1] — 2026-05

### Fixed
- `guides/getting-started.md` — replaced 5 stale rule filenames (`three-failure-stop.md`, `scope-control.md`, `dependency-awareness.md`) with their consolidated targets (`read-before-acting.md`, `scope-discipline.md`). Onboarding adoption path now references files that exist.
- `guides/from-beginner-to-framework.md` — replaced 3 stale rule filenames with their consolidated targets. Symptom-to-rule table and "Where to Start" list now route to live files.

---

## [1.3] — 2026-04

### Added
- `LICENSE` — MIT
- `CHANGELOG.md` — this file
- `INCIDENTS.md` — 23 sanitized incident log entries linking failures to the rules they produced
- `SECURITY.md` — minimal security policy
- `CONTRIBUTING.md` — PR bar: rules require named production incidents
- `.github/ISSUE_TEMPLATE/bug_report.md` and `rule_proposal.md`
- **read-before-acting Gate 3a** — curl before stripping: never remove a parameter from a working API call without running the full flow without it first
- **read-before-acting Gate 4** — map evidence to claim: proxy evidence (grep, glob, SQL-exists) requires proxy language in claims, not assertion language
- **scope-discipline Gate 5** — dormant code check: grep for callers before proposing any remediation plan; zero callers = dormant code; ceremony must match blast radius
- **session-lifecycle Phase 3 Step 6** — weekly `/doctor` run to catch orphan plugin references, path-escape errors, and MCP server failures before they compound as invisible token tax
- `examples/hooks/README.md` — macOS/Linux/WSL platform caveat
- Author block in README with LinkedIn

### Changed
- README tagline and "What This Is" scope — accurate copy replacing over-claim
- `AGENT_FRAMEWORK.md` version bumped to v1.3

---

## [1.2] — 2026-04

### Added
- **Consolidated rules:** 6 rules replaced the prior set of individual files. Each absorbs related concerns into sub-gates.
- **Hook examples:** 4 production-quality shell scripts demonstrating the breadcrumb-based enforcement pattern (`read-gate.sh`, `search-gate.sh`, `delivery-gate.sh`, `deprecated-field-gate.sh`)
- **Delivery protocol rule:** `delivery-protocol.md` — full Build → Store → Deploy → Remember → Log workflow
- **Rule consolidation guide:** `guides/rule-consolidation.md` — how to go from 20+ rules back to ~6 without losing lessons
- **Enforcement architecture guide:** expanded with concrete examples and the block-don't-nag principle

### Changed
- Section 2 restructured around the Four Gates pattern
- Section 3 replaced Scope Control and Process Before Execution with Scope Discipline (four gates)
- Section 5 added Hooks as an explicit third enforcement tier

---

## [1.1] — 2026-03

### Added
- Consistency layer for session-to-session coherence
- Library guides: enforcement architecture, auto-optimization, beginner path
- 3 new rules covering session lifecycle, delivery, and infrastructure

---

## [1.0] — 2026-03

### Added
- Initial framework: project identity, evidence-first culture, circuit breakers, quality gates, self-improvement loop
- Core principle: memory (advice) → rules (law) → hooks (barriers)
