"""Tests for handoff_parser — covers 3 DC body formats + no-DC sparse case."""
from pathlib import Path
import sys

# Add repo root to path so 'examples.evals.lib...' resolves
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from examples.evals.lib.handoff_parser import parse_handoff

FIXTURES = Path(__file__).parent / "fixtures"


def test_parse_complete_handoff_numbered_format():
    """Original plan format: numbered list with trailing ✅/❌."""
    result = parse_handoff(FIXTURES / "handoff_complete.md")
    assert result.session_date == "2026-05-08"
    assert result.machine == "mac"
    assert result.cost_usd == 3.42
    assert result.tokens_input == 120000
    assert len(result.done_criteria) == 3
    assert all(dc.met for dc in result.done_criteria)
    assert result.dc_met_count() == 3
    assert result.dc_total_count() == 3


def test_parse_partial_handoff_with_failures():
    """Numbered format with ❌ markers."""
    result = parse_handoff(FIXTURES / "handoff_partial.md")
    assert len(result.done_criteria) == 2
    assert all(not dc.met for dc in result.done_criteria)
    assert result.dc_met_count() == 0
    assert result.dc_total_count() == 2
    assert "OCR" in result.errors


def test_parse_table_format_dc():
    """Real-world format A: markdown table with ✅ MET in Status column.

    Header is '## Done Criteria — Promise vs Delivery' — must match prefix.
    """
    result = parse_handoff(FIXTURES / "handoff_table_format.md")
    assert result.dc_total_count() == 3
    assert result.dc_met_count() == 3
    assert result.errors  # "## Errors / Blockers Encountered" section is non-empty


def test_parse_inline_emoji_format_dc():
    """Real-world format B: inline '✅ item · ✅ item' list.

    Header is '## Done Criteria — all 14 PASSED' — must match prefix.
    """
    result = parse_handoff(FIXTURES / "handoff_inline_emoji.md")
    assert result.dc_total_count() == 14
    assert result.dc_met_count() == 14


def test_parse_handoff_with_no_dc_section():
    """Sparse signal — no ## Done Criteria heading at all.

    Per Phase 0 baseline: 41 of 47 handoffs in the 14-day window are like this.
    Must return zero counts, not crash.
    """
    result = parse_handoff(FIXTURES / "handoff_no_dc.md")
    assert result.dc_total_count() == 0
    assert result.dc_met_count() == 0
    assert result.done_criteria == []
    assert result.session_date == "2026-04-27"
    assert result.machine == "mac"
