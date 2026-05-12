"""Cost grader — reads cost + tokens from handoff frontmatter.

Frontmatter is populated by cc-analytics (existing tool). When fields are
missing, returns None values — the harness handles None gracefully and
does not crash.
"""
from __future__ import annotations

from examples.evals.lib.handoff_parser import Handoff


def grade_cost(handoff: Handoff) -> dict:
    return {
        "cost_usd": handoff.cost_usd,
        "tokens_input": handoff.tokens_input,
        "tokens_output": handoff.tokens_output,
    }
