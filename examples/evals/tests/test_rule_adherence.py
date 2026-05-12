"""Tests for rule_adherence grader."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from examples.evals.lib.handoff_parser import parse_handoff
from examples.evals.graders.rule_adherence import grade_rule_adherence

FIXTURES = Path(__file__).parent / "fixtures"


def test_clean_session_no_errors_scores_max():
    """All DC met, no errors section → 10.0 (gold-set Session B baseline)."""
    h = parse_handoff(FIXTURES / "handoff_complete.md")
    score, evidence = grade_rule_adherence(h)
    assert score == 10.0
    assert evidence["violations"] == []


def test_session_with_errors_section_loses_one_point():
    """Errors section non-empty → -1.0 penalty (gold-set Session A baseline)."""
    h = parse_handoff(FIXTURES / "handoff_table_format.md")
    score, evidence = grade_rule_adherence(h)
    assert score == 9.0
    assert "errors_section_nonempty" in evidence["violations"]


def test_session_with_partial_dc_loses_half_point():
    """Some DC items unmet → -0.5 penalty stacked on top of errors penalty."""
    h = parse_handoff(FIXTURES / "handoff_partial.md")
    score, evidence = grade_rule_adherence(h)
    # errors -1.0 + dc_partial -0.5 = 8.5
    assert score == 8.5
    assert "errors_section_nonempty" in evidence["violations"]
    assert "dc_partial" in evidence["violations"]


def test_violation_language_broader_than_blocked_by_gate():
    """Phase 0 finding: 0/47 handoffs use 'blocked by gate'.

    Broader regex must catch denied / rejected / halted / aborted / hook failed.
    """
    # Synthetic body with violation language
    from examples.evals.lib.handoff_parser import Handoff
    h = Handoff(
        session_date="2026-05-01",
        machine="mac",
        body="The exchange-first hook denied the write. Aborted operation.",
    )
    score, evidence = grade_rule_adherence(h)
    assert evidence["blocked_mentions"] >= 1
    assert score < 10.0


def test_no_dc_session_no_errors_scores_max():
    """Sparse-signal case (gold-set Session C): no DC, no errors, clean run."""
    h = parse_handoff(FIXTURES / "handoff_no_dc.md")
    score, evidence = grade_rule_adherence(h)
    assert score == 10.0
    assert evidence["violations"] == []
