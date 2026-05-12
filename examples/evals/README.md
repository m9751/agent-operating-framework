# AOF Eval Harness

Self-applied evaluation of the operator's daily AOF use. Grades 4 metric families per session, persists to `smokin-ops.eval.{sessions,runs}`, surfaces at `aof-eval.vercel.app` (dashboard ships in Phase 4 of the build plan).

## Why

The hypocrisy test: if AOF is real discipline, it has to be able to measure itself. v1 ships deterministic graders so the baseline is auditable; v2 layers in hook-log integration and (optionally) an LLM judge for plan-delivery nuance.

## Usage

### Dry-run (no writes, no Supabase needed)

```bash
python -m examples.evals.run_harness --window-days 14 --dry-run
```

### Production run

```bash
export SMOKIN_OPS_URL="https://xuvdcygqyuajtlpavafr.supabase.co"
export SMOKIN_OPS_SERVICE_KEY="<service_role key from Supabase dashboard>"
pip install --user supabase==2.6.0
python -m examples.evals.run_harness --window-days 7 --trigger cron
```

### Backfill (Phase 3 first-run)

```bash
python -m examples.evals.run_harness --window-days 14 --trigger backfill
```

## Metrics

| Metric | Range | How it's computed |
|---|---|---|
| **Rule adherence** | 0–10 | Deterministic. Penalties: errors section non-empty (-1.0), DC partial (-0.5), violation language in body (-1.5 per mention). |
| **Plan→delivery gap** | 0–10 or None | `10 * dc_met / dc_total`. Returns None when the handoff has no Done Criteria section. |
| **Cost** | $ + tokens | Read from handoff frontmatter (populated by cc-analytics). None-safe. |
| **Dispatch quality** | None (v1) | Stub. Lit up in v2 when hook log integration ships. |
| **Composite** | 0–10 | `0.6 * rule + 0.4 * plan`. Falls back to rule-only when plan is None. |

## Done Criteria body formats supported

The parser handles 3 real-world formats found in the Phase 0 baseline corpus:

1. Numbered list: `1. text ✅` / `1. text ❌`
2. Markdown table: `| 1 | text | ✅ MET | ... |`
3. Inline emoji: `✅ item · ✅ item · ❌ item`

Header match is prefix-anchored — `## Done Criteria — Promise vs Delivery` and `## Done Criteria — all 14 PASSED` both qualify.

## v1 limitations

- Dispatch quality is None until hook log integration (v2).
- Cost is None for most handoffs because frontmatter isn't yet populated by cc-analytics for every session.
- Deterministic only — no LLM judge until baseline is stable.

## Schema

`eval.sessions` + `eval.runs` on smokin-ops project `xuvdcygqyuajtlpavafr`. Migrations live in `m9751/smokin-ops/supabase/migrations/` (PR #15 merged 2026-05-11).

## Tests

```bash
cd ~/repos/agent-operating-framework
python -m pytest examples/evals/tests/ -v
```

14/14 tests pass on every commit. Fixtures cover all 3 DC body formats + sparse-signal case.
