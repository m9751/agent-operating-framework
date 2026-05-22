# Changelog

All notable changes to this framework follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

---

## [1.6] — 2026-05 (DRAFT — not yet tagged)

### Context for the author of this release

This entry was drafted in two passes:
- **Pass 1 (2026-05-21)** — after a full night of operational work that generated the raw material for v1.6: the 29-hook audit, the breadcrumb-lib v1 ship (PR #65), the bypass and telemetry designs, and the "three questions nobody asks" framing.
- **Pass 2 (2026-05-22)** — a second night that landed PRs #68, #71, #72 on `m9751/claude-config` and surfaced three additional patterns: SCHEMA ASSUMPTION comment blocks, cross-subprocess PID stability as a regression-test requirement, and `PUSH-SKIPPED` for watcher hooks under branch protection.

Before writing the release, read these source artifacts:

| Item | Where to find the details |
|---|---|
| Full hook audit methodology | `~/.claude/plans/2026-05-21-full-hook-audit-wbs.md` — 4-track WBS, Codex batch audit pattern across 5 event types, triage table format. The audit covered 29 registered hooks on Mac. |
| Blast-radius annotation standard | Already in AOF v1.4+. But the private implementation revealed that Codex will reject any hook missing `# fail-mode:` and `# blast-radius:` even if the logic is correct. The fix in `~/repos/claude-config/hooks/` is the reference — all 29 hooks now have it. |
| Breadcrumb protocol v1 | `~/repos/claude-config/hooks/breadcrumb-lib.sh` — shipped PR #65 on `m9751/claude-config`. Five functions: `bc_session_key`, `bc_dir`, `bc_write`, `bc_exists`, `bc_read`. 8 hooks updated to source it. Handoff: `~/Documents/SmokinTerritory/SmokinTerritory/03-Projects/ST2/handoff-mac-20260521-breadcrumb-protocol-shipped.md` |
| Breadcrumb protocol v2 (canonicalization) | PR #68 — `bc_session_key()` made `CLAUDE_CODE_SESSION_ID` canonical primary; `CLAUDE_SESSION_ID` demoted to legacy backstop pending Mac probe. Permanent regression smoke at `tests/smoke/hooks/breadcrumb-lib/smoke.sh` with the cross-subprocess PID stability case the v1 ship smoke missed. Companion retro: `m9751/smokin-mirror/retro/2026-05-22-branch-protection-and-breadcrumb-canonicalization.md`. |
| Watcher push-skip pattern | PR #72 — `win11-event-sync.ps1` skips `git push` step entirely; commit step preserved as automatic local backup. New `# fail-mode: silent-skip` annotation tier. Surfaced when branch protection turned the watcher's hourly push attempts into log-only `PUSH-FAIL` noise. |
| Emergency bypass | Reference implementation: `~/repos/claude-config/hooks/` — `CLAUDE_HOOKS_SAFE_MODE=1` check added to all 13 blocking hooks. Design handoff: `~/Documents/SmokinTerritory/SmokinTerritory/03-Projects/ST2/handoff-mac-20260521-telemetry-and-bypass-design.md` |
| Hook telemetry | Reference implementation: `~/repos/claude-config/hooks/hook-telemetry-stop.sh` — Stop hook reads breadcrumb-lib session data, bulk-INSERTs into `telemetry.hook_events` on smokin-ops. Same design handoff as bypass above. |
| The three questions nobody asks | Conversation from 2026-05-21 session — not in a file yet. See below for the content. |

### The three questions nobody asks (new AOF section)

These belong in a new `guides/hook-operations.md` or as a `§5.5` in `AGENT_FRAMEWORK.md`:

**1. What happens when a hook itself fails?**
If a hook crashes mid-execution — python3 not found, disk full, corrupt stdin — behavior is undefined. Some hooks fail-open silently, some exit with a non-2 code. You have no monitoring on hook health. A broken gate looks identical to a passing gate. The AOF should prescribe: every hook must define its `fail-closed` vs `fail-open` behavior on unexpected errors, and the `# fail-mode:` annotation must cover this case explicitly.

**2. Are these hooks actually changing behavior, or are they theater?**
Without telemetry you cannot distinguish "the gate is working" from "nothing bad happened to test it." The AOF should prescribe: after 2 weeks of deployment, operators should be able to answer which hooks fired, how often, and whether they blocked anything. The `telemetry.hook_events` design (see handoff above) is the reference implementation for this. The 2026-05-22 PR #72 incident is the canonical case study: the Win11 watcher was logging `PUSH-FAIL` ~every 30 seconds for 14 days and nobody noticed until a separate audit caught it. With telemetry on the watcher, this would have surfaced on day 1.

**3. What is the exit strategy if a hook goes rogue?**
There is no fast-disable path in v1.5. The AOF should prescribe a mandatory bypass mechanism for every installation. The `CLAUDE_HOOKS_SAFE_MODE=1` env var pattern (see handoff above) is the reference design: one env var, one line per hook, 30-second recovery during a live session.

### Added (concrete this cycle — from PRs #68, #71, #72)

- **`SCHEMA ASSUMPTION` comment block as a hook-library documentation pattern.** When a hook function depends on a runtime-set env var (e.g., `CLAUDE_CODE_SESSION_ID`), write the assumption as an inline comment block above the function body so a future refactor cannot silently break the contract. Reference implementation: `breadcrumb-lib.sh:bc_session_key()` on `m9751/claude-config` after PR #68. The comment names (a) the canonical source, (b) any legacy backstops kept for compatibility, (c) the fallback-of-last-resort, and (d) the conditions under which the backstop may be removed.
- **Permanent regression smoke under `tests/smoke/hooks/<name>/smoke.sh`.** Every shipped hook library gets a standalone smoke script in this canonical location. The script must include the **cross-subprocess PID stability case** (two separate `bash -c` subprocesses producing identical output) for any function that depends on a session-scoped identifier. The original ship smoke for `breadcrumb-lib.sh` only checked "key != default" and missed per-PID divergence on Win11 — the canonical smoke pattern closes that class of bug. Reference: PR #68 `tests/smoke/hooks/breadcrumb-lib/smoke.sh`.
- **`PUSH-SKIPPED branch-protection-active` log-line pattern for watcher-class hooks.** Hooks that auto-push to a protected branch (FileSystemWatcher daemons, inotify cron) will fail-loop indefinitely on GitHub `GH006: Protected branch update failed`. The v1.6 pattern: keep the auto-commit step (useful as automatic local backup), skip the auto-push step entirely, log `PUSH-SKIPPED <reason>` for auditability, and document the operator's manual PR step as the surfacing path. Reference: `m9751/claude-config` PR #72 retrofitting `win11-event-sync.ps1`.
- **Strategy A reconciliation pattern** for divergent local main against a protected origin: (1) drop a safety tag on origin first with a session-unique suffix; (2) verify the tag landed on origin (HALT if not); (3) `git reset --hard` (or `--keep` if the safety net blocks `--hard`); (4) T+0 / T+5 / T+15 stabilization gate via `git status --porcelain` + `git rev-parse HEAD` captured at three timestamps with pairwise diff. Recovery if anything fails: `git fetch origin --tags && git reset --hard <safety-tag>` — survives reflog pruning AND local-repo loss. Reference incident: post-PR-#68 reconciliation in `m9751/claude-config` (2026-05-22).
- **2 new sanitized incidents** in `INCIDENTS.md`:
  - **#34 — undocumented env var as load-bearing primary.** A breadcrumb library used `CLAUDE_SESSION_ID` (undocumented; set on Mac via shell init, empty on Win11) as its primary session key for ~14 days. Source-truth-write-gate silently rejected legitimate writes on Win11 the entire time. Lesson: hook libraries should depend on a documented runtime contract; if an env var is the primary key, an inline `SCHEMA ASSUMPTION` block must name the runtime that exports it and the platforms verified.
  - **#35 — watcher hook silently broken by branch protection.** Watcher hook on Win11 was logging `PUSH-FAIL` for ~14 days because branch protection on `main` required PR. Symptom: local main perpetually divergent from origin/main; cosmetic but not functionally broken. Lesson: any hook that runs `git push origin <protected-branch>` must surface push-rejection to the operator (status file, foreground log) rather than degrade silently to log-and-skip-next-iteration.

### Changed (concrete this cycle)

- **`AGENT_FRAMEWORK.md` §5.2 fail-mode taxonomy** — adds `# fail-mode: silent-skip` as a new tier for watcher-class hooks that intentionally accept-and-log a non-error condition (e.g., branch-protected push). Distinguishes from `# fail-mode: open` (which means "the hook is advisory; failure of the hook itself is acceptable") and `# fail-mode: closed` (which means "the hook blocks on detection"). Silent-skip is "the hook detected a runtime condition that requires the operator's attention but does not block the build."
- **`examples/hooks/README.md`** — adds a "Watcher hooks under branch-protected repos" section pointing at the `PUSH-SKIPPED` pattern.
- **`guides/advanced/hook-design-patterns.md`** (or wherever the canonical pattern doc lives in this framework's repo — confirm location) — new "Session-scoped identifier hygiene" section covering: canonical env var selection, the `SCHEMA ASSUMPTION` comment block, cross-subprocess PID stability tests, and how to retire legacy backstops via an empirical platform probe (e.g., the `printenv | grep -i <name>` probe pattern used for the Mac follow-up to PR #68).
- `AGENT_FRAMEWORK.md` version bumped to v1.6.

### Planned additions still pending for v1.6 tag

- **`guides/hook-operations.md`** — new guide covering the three questions above, with reference implementations for bypass and telemetry
- **`examples/hooks/breadcrumb-lib.sh`** — shared breadcrumb library (port from `m9751/claude-config` PR #65 + PR #68 canonicalization)
- **`guides/advanced/hook-audit-methodology.md`** — 4-track audit WBS pattern, Codex batch audit format, triage table schema
- **Updated `AGENT_FRAMEWORK.md` §5** — add breadcrumb protocol as a standard pattern; add emergency bypass as a mandatory deployment requirement; update hook annotation standard to flag the `fail-on-error` case
- **Eval harness tag** — `b3d8451` is on main but untagged; v1.6 tag will capture it

### What is NOT in v1.6 (deferred to AOF examples)

- `telemetry.hook_events` schema — implemented in private smokin-ops; needs sanitized port to `examples/` before v1.6 tags
- `CLAUDE_HOOKS_SAFE_MODE` bypass — implemented in private claude-config hooks; needs sanitized port to `examples/hooks/` before v1.6 tags
- `hook-telemetry-stop.sh` — implemented in private claude-config; same port requirement

### Release checklist

- [x] Document SCHEMA ASSUMPTION comment block pattern (this CHANGELOG)
- [x] Document `PUSH-SKIPPED branch-protection-active` pattern (this CHANGELOG)
- [x] Document Strategy A reconciliation pattern (this CHANGELOG)
- [x] Add `# fail-mode: silent-skip` taxonomy tier (this CHANGELOG; AGENT_FRAMEWORK.md §5.2 update pending)
- [x] Sanitized incidents #34 + #35 outlined (port to `INCIDENTS.md` pending)
- [ ] Write `guides/hook-operations.md` (three questions content above)
- [ ] Port `breadcrumb-lib.sh` from claude-config (PR #65 + PR #68) to `examples/hooks/`
- [ ] Write `guides/advanced/hook-audit-methodology.md`
- [ ] Update `AGENT_FRAMEWORK.md` §5 matrix and narrative
- [ ] Update `AGENT_FRAMEWORK.md` §5.2 with `silent-skip` tier
- [ ] Append `INCIDENTS.md` #34 + #35
- [ ] Verify eval harness (`b3d8451`) is clean and functional
- [ ] Update version references in `AGENT_FRAMEWORK.md`
- [ ] `git tag v1.6 && git push --tags`
- [ ] Create GitHub release with these CHANGELOG notes

### Origin

This v1.6 release notes draft consolidates two consecutive overnight sessions (2026-05-21 and 2026-05-22). The 2026-05-21 session shipped breadcrumb-lib v1 (PR #65 on `m9751/claude-config`) plus the full 29-hook audit + bypass/telemetry designs. The 2026-05-22 session shipped breadcrumb-lib v2 canonicalization (PR #68), the MEMORY.md atomic-attribution pattern (PR #71), and the watcher push-skip retrofit (PR #72). The companion narrative retro for the 2026-05-22 work lives at `m9751/smokin-mirror/retro/2026-05-22-branch-protection-and-breadcrumb-canonicalization.md`. Together they form the empirical basis for v1.6.

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
