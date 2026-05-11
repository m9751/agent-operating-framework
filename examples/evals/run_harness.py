"""AOF eval harness — main entrypoint.

Usage:
  python -m examples.evals.run_harness --window-days 14 --dry-run
  python -m examples.evals.run_harness --window-days 7 --trigger cron --github-run-id $GITHUB_RUN_ID

The harness walks handoff notes in the window, grades each session on 4
deterministic metrics (rule adherence, plan-delivery gap, cost, dispatch),
and (unless --dry-run) persists results to smokin-ops.eval.{sessions,runs}.
"""
from __future__ import annotations

import argparse
import sys
from datetime import date, timedelta
from pathlib import Path
from statistics import mean
from typing import Optional

# Allow `python -m examples.evals.run_harness` to find sibling packages.
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from examples.evals.lib.handoff_parser import parse_handoff
from examples.evals.graders.rule_adherence import grade_rule_adherence
from examples.evals.graders.plan_delivery_gap import grade_plan_delivery
from examples.evals.graders.cost import grade_cost
from examples.evals.graders.dispatch_quality import grade_dispatch_quality

HARNESS_VERSION = "v1.0"
DEFAULT_HANDOFF_DIR = (
    Path.home() / "Documents/SmokinTerritory/SmokinTerritory/03-Projects/ST2"
)


def composite(rule_score: float, plan_score: Optional[float]) -> float:
    """0.6 * rule + 0.4 * plan, falling back to rule-only when plan is None."""
    if plan_score is None:
        return round(rule_score, 2)
    return round(0.6 * rule_score + 0.4 * plan_score, 2)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-days", type=int, default=14)
    ap.add_argument(
        "--trigger", choices=["manual", "cron", "backfill"], default="manual"
    )
    ap.add_argument("--github-run-id", default=None)
    ap.add_argument("--aof-version", default="v1.5")
    ap.add_argument("--handoff-dir", default=str(DEFAULT_HANDOFF_DIR))
    ap.add_argument(
        "--dry-run", action="store_true", help="Grade only, no Supabase writes"
    )
    args = ap.parse_args()

    window_end = date.today()
    window_start = window_end - timedelta(days=args.window_days)
    handoffs = sorted(Path(args.handoff_dir).glob("handoff-*.md"))

    in_window: list[tuple[Path, object]] = []
    for h in handoffs:
        try:
            parsed = parse_handoff(h)
            sd = parsed.session_date
            if sd and window_start.isoformat() <= sd <= window_end.isoformat():
                in_window.append((h, parsed))
        except Exception as e:
            print(f"skip {h.name}: {e}", file=sys.stderr)

    if not in_window:
        print(
            f"No handoffs in window {window_start}..{window_end}", file=sys.stderr
        )
        return 1

    print(
        f"Grading {len(in_window)} sessions in window {window_start}..{window_end}"
    )

    graded = []
    for path, handoff in in_window:
        rule = grade_rule_adherence(handoff)
        plan = grade_plan_delivery(handoff)
        cost = grade_cost(handoff)
        dispatch = grade_dispatch_quality(handoff)
        comp = composite(rule[0], plan[0])
        graded.append(
            {
                "path": str(path),
                "handoff": handoff,
                "rule": rule,
                "plan": plan,
                "cost": cost,
                "dispatch": dispatch,
                "composite": comp,
            }
        )
        plan_display = (
            f"{plan[0]:.1f}" if plan[0] is not None else "n/a"
        )
        print(
            f"  {handoff.session_date} {path.name}: "
            f"rule={rule[0]:.1f} plan={plan_display} comp={comp:.1f}"
        )

    rule_scores = [g["rule"][0] for g in graded]
    plan_scores = [g["plan"][0] for g in graded if g["plan"][0] is not None]
    comp_scores = [g["composite"] for g in graded]
    total_cost = sum((g["cost"].get("cost_usd") or 0) for g in graded)
    total_tokens = sum(
        ((g["cost"].get("tokens_input") or 0) + (g["cost"].get("tokens_output") or 0))
        for g in graded
    )

    summary = {
        "mean_rule": round(mean(rule_scores), 2),
        "mean_plan": round(mean(plan_scores), 2) if plan_scores else None,
        "mean_composite": round(mean(comp_scores), 2),
        "total_cost_usd": round(total_cost, 2),
        "total_tokens": total_tokens,
        "sessions_with_dc": len(plan_scores),
        "sessions_without_dc": len(graded) - len(plan_scores),
    }
    print(f"\nSummary: {summary}")

    if args.dry_run:
        print("--dry-run: skipping Supabase writes")
        return 0

    # Real-write path imported lazily to avoid supabase-py at dry-run time
    from examples.evals.lib.supabase_client import insert_run, insert_session

    run_id = insert_run(
        window_start=window_start.isoformat(),
        window_end=window_end.isoformat(),
        sessions_graded=len(graded),
        mean_rule_adherence=summary["mean_rule"],
        mean_plan_delivery=summary["mean_plan"],
        mean_composite=summary["mean_composite"],
        total_cost_usd=summary["total_cost_usd"],
        total_tokens=summary["total_tokens"],
        harness_version=HARNESS_VERSION,
        aof_version=args.aof_version,
        trigger_kind=args.trigger,
        github_run_id=args.github_run_id,
    )
    print(f"Inserted eval.runs id={run_id}")

    for g in graded:
        insert_session(
            run_id=run_id,
            handoff_path=g["path"],
            session_date=g["handoff"].session_date,
            machine=g["handoff"].machine,
            rule_adherence=g["rule"],
            plan_delivery=g["plan"],
            cost=g["cost"],
            dispatch=g["dispatch"],
            composite=g["composite"],
        )
    print(f"Inserted {len(graded)} eval.sessions rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
