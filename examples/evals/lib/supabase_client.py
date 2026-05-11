"""Thin Supabase client wrapper for smokin-ops eval schema.

Imports supabase-py lazily so --dry-run works without the dependency installed.
"""
from __future__ import annotations

import os
from typing import Optional


def _client():
    """Lazy-import + connect. Raises a clear error if creds or library missing."""
    try:
        from supabase import create_client  # type: ignore
    except ImportError as e:
        raise RuntimeError(
            "supabase-py not installed. Run: pip install --user supabase==2.6.0"
        ) from e

    url = os.environ.get("SMOKIN_OPS_URL")
    key = os.environ.get("SMOKIN_OPS_SERVICE_KEY")
    if not url or not key:
        raise RuntimeError(
            "Set SMOKIN_OPS_URL and SMOKIN_OPS_SERVICE_KEY env vars before running "
            "without --dry-run."
        )
    return create_client(url, key)


def insert_run(
    *,
    window_start: str,
    window_end: str,
    sessions_graded: int,
    mean_rule_adherence: float,
    mean_plan_delivery: Optional[float],
    mean_composite: float,
    total_cost_usd: float,
    total_tokens: int,
    harness_version: str,
    aof_version: str,
    trigger_kind: str,
    github_run_id: Optional[str] = None,
    notes: Optional[str] = None,
) -> str:
    """Insert one row into eval.runs, return the new id."""
    c = _client()
    payload = {
        "window_start": window_start,
        "window_end": window_end,
        "sessions_graded": sessions_graded,
        "mean_rule_adherence": mean_rule_adherence,
        "mean_plan_delivery": mean_plan_delivery,
        "mean_composite": mean_composite,
        "total_cost_usd": total_cost_usd,
        "total_tokens": total_tokens,
        "harness_version": harness_version,
        "aof_version": aof_version,
        "trigger_kind": trigger_kind,
        "github_run_id": github_run_id,
        "notes": notes,
    }
    res = c.schema("eval").table("runs").insert(payload).execute()
    return res.data[0]["id"]


def insert_session(
    *,
    run_id: str,
    handoff_path: str,
    session_date: str,
    machine: str,
    rule_adherence: tuple[float, dict],
    plan_delivery: tuple[Optional[float], dict],
    cost: dict,
    dispatch: tuple[Optional[float], dict],
    composite: float,
) -> None:
    """Insert one row into eval.sessions, FK-linked to a run."""
    c = _client()
    c.schema("eval").table("sessions").insert(
        {
            "run_id": run_id,
            "handoff_path": handoff_path,
            "session_date": session_date,
            "machine": machine,
            "rule_adherence_score": rule_adherence[0],
            "rule_adherence_evidence": rule_adherence[1],
            "plan_delivery_score": plan_delivery[0],
            "plan_delivery_evidence": plan_delivery[1],
            "session_cost_usd": cost.get("cost_usd"),
            "session_tokens_input": cost.get("tokens_input"),
            "session_tokens_output": cost.get("tokens_output"),
            "dispatch_score": dispatch[0],
            "dispatch_evidence": dispatch[1],
            "composite_score": composite,
        }
    ).execute()
