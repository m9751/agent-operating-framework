"""Wrapper that dumps the harness output as JSON for ingestion via Supabase MCP.

Used in Phase 3 when supabase-py isn't installed but the Supabase MCP is available.
Run-once helper, not part of the production harness.
"""
from __future__ import annotations

import json
import sys
from datetime import date, timedelta
from pathlib import Path
from statistics import mean

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from examples.evals.lib.handoff_parser import parse_handoff
from examples.evals.graders.rule_adherence import grade_rule_adherence
from examples.evals.graders.plan_delivery_gap import grade_plan_delivery
from examples.evals.graders.cost import grade_cost
from examples.evals.graders.dispatch_quality import grade_dispatch_quality
from examples.evals.run_harness import composite, HARNESS_VERSION, DEFAULT_HANDOFF_DIR

WINDOW_DAYS = 14


def main():
    window_end = date.today()
    window_start = window_end - timedelta(days=WINDOW_DAYS)
    handoffs = sorted(DEFAULT_HANDOFF_DIR.glob("handoff-*.md"))

    graded = []
    for h in handoffs:
        try:
            handoff = parse_handoff(h)
        except Exception:
            continue
        sd = handoff.session_date
        if not sd or not (window_start.isoformat() <= sd <= window_end.isoformat()):
            continue
        rule = grade_rule_adherence(handoff)
        plan = grade_plan_delivery(handoff)
        cost = grade_cost(handoff)
        dispatch = grade_dispatch_quality(handoff)
        comp = composite(rule[0], plan[0])
        graded.append(
            {
                "handoff_path": str(h),
                "session_date": handoff.session_date,
                "machine": handoff.machine,
                "rule_adherence_score": rule[0],
                "rule_adherence_evidence": rule[1],
                "plan_delivery_score": plan[0],
                "plan_delivery_evidence": plan[1],
                "session_cost_usd": cost.get("cost_usd"),
                "session_tokens_input": cost.get("tokens_input"),
                "session_tokens_output": cost.get("tokens_output"),
                "dispatch_score": dispatch[0],
                "dispatch_evidence": dispatch[1],
                "composite_score": comp,
            }
        )

    rule_scores = [g["rule_adherence_score"] for g in graded]
    plan_scores = [g["plan_delivery_score"] for g in graded if g["plan_delivery_score"] is not None]
    comp_scores = [g["composite_score"] for g in graded]

    run = {
        "window_start": window_start.isoformat(),
        "window_end": window_end.isoformat(),
        "sessions_graded": len(graded),
        "mean_rule_adherence": round(mean(rule_scores), 2) if rule_scores else None,
        "mean_plan_delivery": round(mean(plan_scores), 2) if plan_scores else None,
        "mean_composite": round(mean(comp_scores), 2) if comp_scores else None,
        "total_cost_usd": round(sum((g["session_cost_usd"] or 0) for g in graded), 2),
        "total_tokens": sum(
            ((g["session_tokens_input"] or 0) + (g["session_tokens_output"] or 0))
            for g in graded
        ),
        "harness_version": HARNESS_VERSION,
        "aof_version": "v1.5",
        "trigger_kind": "backfill",
    }

    output = {"run": run, "sessions": graded}
    print(json.dumps(output, default=str))


if __name__ == "__main__":
    main()
