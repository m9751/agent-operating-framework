# Gold Set — Phase 0 Manual Grades

3 sessions hand-scored 2026-05-11 to validate Phase 2 harness output. Drift threshold: < 10% per metric.

---

## Session A — USACS POV + Beacon RLS Fix

```yaml
handoff_path: handoff-mac-20260507-usacs-pov-beacon-rls-fix.md
session_date: 2026-05-07
machine: mac

rule_adherence_score: 9.0
rule_adherence_evidence:
  blocked_by_gate_or_similar: 0
  errors_section_nonempty: true   # "## Errors / Blockers Encountered" present
  dc_partial: false                # all 8 met
  notes: "Errors were encountered AND resolved during the session, hence -1.0 penalty for nonempty errors, but full credit on DC."

plan_delivery_score: 10.0
plan_delivery_evidence:
  dc_count: 8
  dc_met: 8
  gaps: []
  format: "markdown_table_with_emoji"

session_cost_usd: null  # frontmatter doesn't include cost
session_tokens_input: null
session_tokens_output: null

dispatch_score: null  # v1 stub, no hook log

composite_score: 9.4   # 0.6 * 9.0 + 0.4 * 10.0
```

---

## Session B — Momentum Architecture Read

```yaml
handoff_path: handoff-mac-20260505-momentum-architecture-read.md
session_date: 2026-05-05
machine: mac

rule_adherence_score: 10.0
rule_adherence_evidence:
  blocked_by_gate_or_similar: 0
  errors_section_nonempty: false   # Errors section is empty or absent
  dc_partial: false                 # all 14 met
  notes: "Clean session, full marks."

plan_delivery_score: 10.0
plan_delivery_evidence:
  dc_count: 14
  dc_met: 14
  gaps: []
  format: "inline_emoji_list"       # ✅ File exists · ✅ Renders · ...

session_cost_usd: null
session_tokens_input: null
session_tokens_output: null

dispatch_score: null

composite_score: 10.0   # 0.6 * 10 + 0.4 * 10
```

---

## Session C — Turenne PharMedCo (sparse signal)

```yaml
handoff_path: handoff-mac-20260427-turenne-pharmedco.md
session_date: 2026-04-27
machine: mac

rule_adherence_score: 10.0
rule_adherence_evidence:
  blocked_by_gate_or_similar: 0
  errors_section_nonempty: false   # No errors section
  dc_partial: false                 # No DC, no partial penalty
  notes: "Clean status=in-progress session, account-research type, no rule violations or errors."

plan_delivery_score: null           # NO ## Done Criteria block — sparse signal
plan_delivery_evidence:
  dc_count: 0
  dc_met: 0
  gaps: []
  format: "absent"

session_cost_usd: null
session_tokens_input: null
session_tokens_output: null

dispatch_score: null

composite_score: 10.0   # falls back to rule-only because plan is null
```

---

## Grader implications

1. **DC header regex** must be `^##\s+Done Criteria` (prefix-anchored, allows " — Promise vs Delivery" / " — all N PASSED" suffixes), NOT exact match.
2. **DC body parser** needs 3 format handlers:
   - Markdown table rows with ✅/❌ emoji in a Status column
   - Inline `✅ item · ✅ item` lists (count emoji occurrences)
   - Numbered `1. text ✅` (original plan format)
3. **Rule penalty heuristics** must broaden beyond literal "blocked by gate":
   - Match `(denied|rejected|halted|aborted|hook failed|hook blocked|blocked by gate)` case-insensitive
   - Treat `^## Errors` non-empty as -1.0 (most common signal in real handoffs)
4. **Cost fields** are usually null in current handoff frontmatter — grader must handle this gracefully and not crash. Composite computed even when cost is null.
5. **Dispatch is v1 stub** — gold-set codifies that `dispatch_score: null` is correct, not failure.
