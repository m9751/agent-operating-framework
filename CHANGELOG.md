# Changelog

All notable changes to this framework follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

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
