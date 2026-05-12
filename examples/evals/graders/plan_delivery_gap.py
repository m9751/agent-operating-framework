"""Plan→delivery gap grader — ratio of Done Criteria met.

Returns None when the handoff has no DC section (sparse-signal case).
Composite scoring (in run_harness.py) falls back to rule-only when this
grader returns None — that's the correct behavior, not a failure.
"""
from __future__ import annotations

from typing import Optional

from examples.evals.lib.handoff_parser import Handoff


def grade_plan_delivery(handoff: Handoff) -> tuple[Optional[float], dict]:
    total = handoff.dc_total_count()
    met = handoff.dc_met_count()
    evidence: dict = {"dc_count": total, "dc_met": met, "gaps": []}

    if total == 0:
        return None, evidence

    for dc in handoff.done_criteria:
        if not dc.met:
            evidence["gaps"].append(dc.text)

    score = round(10.0 * met / total, 2)
    return score, evidence
