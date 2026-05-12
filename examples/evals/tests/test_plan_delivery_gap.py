"""Tests for plan_delivery_gap grader."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from examples.evals.lib.handoff_parser import parse_handoff, Handoff
from examples.evals.graders.plan_delivery_gap import grade_plan_delivery

FIXTURES = Path(__file__).parent / "fixtures"


def test_all_dc_met_scores_10():
    h = parse_handoff(FIXTURES / "handoff_complete.md")
    score, evidence = grade_plan_delivery(h)
    assert score == 10.0
    assert evidence["dc_met"] == 3
    assert evidence["dc_count"] == 3
    assert evidence["gaps"] == []


def test_zero_dc_met_scores_0():
    h = parse_handoff(FIXTURES / "handoff_partial.md")
    score, evidence = grade_plan_delivery(h)
    assert score == 0.0
    assert evidence["dc_met"] == 0
    assert evidence["dc_count"] == 2
    assert len(evidence["gaps"]) == 2


def test_no_dc_section_returns_none():
    """Sparse-signal case: no DC at all → None, not 0.

    Per Phase 0: 41 of 47 handoffs in the 14-day window. Composite must
    fall back to rule-only when plan is None.
    """
    h = parse_handoff(FIXTURES / "handoff_no_dc.md")
    score, evidence = grade_plan_delivery(h)
    assert score is None
    assert evidence["dc_count"] == 0
    assert evidence["dc_met"] == 0


def test_partial_dc_ratio_rounds_to_2_decimals():
    """5 of 7 met → 7.14, not 7.142857..."""
    h = Handoff(
        session_date="2026-05-01",
        machine="mac",
        done_criteria=[
            type("DC", (), {"text": f"item {i}", "met": i < 5})()
            for i in range(7)
        ],
    )
    score, evidence = grade_plan_delivery(h)
    assert score == 7.14
    assert evidence["dc_met"] == 5
    assert evidence["dc_count"] == 7
