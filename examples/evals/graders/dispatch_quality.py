"""Dispatch quality grader — v1 stub.

Returns None until hook log integration ships in v2. The eval.sessions
schema allows dispatch_score NULL specifically for this case; the gold-set
codifies that None is correct for v1, not a failure.
"""
from __future__ import annotations

from typing import Optional

from examples.evals.lib.handoff_parser import Handoff


def grade_dispatch_quality(handoff: Handoff) -> tuple[Optional[float], dict]:
    return None, {
        "note": "v1 stub — requires hook log integration to grade dispatch routing",
        "opus_calls": None,
        "haiku_calls": None,
    }
