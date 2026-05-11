"""Rule adherence grader — scores 0-10 based on hook-gate breadcrumbs and handoff errors.

Penalties (subtracted from 10):
  - blocked_by_gate: 1.5 per mention (matched broadly per Phase 0 finding —
    no handoffs use literal 'blocked by gate', so we widen to denied/rejected/
    halted/aborted/hook failed/hook blocked)
  - errors_section_nonempty: 1.0 (most common signal — 27 of 47 handoffs)
  - dc_partial: 0.5 (when Done Criteria are present but not all met)
"""
from __future__ import annotations

import re

from examples.evals.lib.handoff_parser import Handoff

# Broader violation regex — case-insensitive
_VIOLATION_RE = re.compile(
    r"\b(blocked by gate|hook blocked|hook failed|denied|rejected|halted|aborted)\b",
    re.IGNORECASE,
)

VIOLATION_PENALTIES = {
    "blocked_by_gate": 1.5,
    "errors_section_nonempty": 1.0,
    "dc_partial": 0.5,
}


def grade_rule_adherence(handoff: Handoff) -> tuple[float, dict]:
    violations: list[str] = []
    score = 10.0

    if handoff.errors:
        violations.append("errors_section_nonempty")
        score -= VIOLATION_PENALTIES["errors_section_nonempty"]

    if handoff.dc_total_count() > 0 and handoff.dc_met_count() < handoff.dc_total_count():
        violations.append("dc_partial")
        score -= VIOLATION_PENALTIES["dc_partial"]

    blocked_mentions = len(_VIOLATION_RE.findall(handoff.body or ""))
    if blocked_mentions:
        violations.append("blocked_by_gate")
        score -= VIOLATION_PENALTIES["blocked_by_gate"] * blocked_mentions

    score = max(0.0, min(10.0, score))
    evidence = {
        "violations": violations,
        "blocked_mentions": blocked_mentions,
        "errors_present": bool(handoff.errors),
    }
    return score, evidence
