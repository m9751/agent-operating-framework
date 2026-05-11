# AOF Eval Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-applied evaluation harness that measures rule adherence, plan-delivery gap, cost, and tool/skill dispatch quality across Michael's daily AOF usage, persists results to smokin-ops, and surfaces a weekly dashboard at aof-eval.vercel.app.

**Architecture:** Deterministic Python grader walks last-14-days handoff notes + cc-analytics output, scores 4 metric families per session, writes to `eval.sessions` + `eval.runs` on smokin-ops, surfaces aggregates via Next.js dashboard on a dedicated Vercel project. Weekly cron (Sun 10am local) re-runs the harness. No LLM judge in v1.

**Tech Stack:** Python 3.11 (stdlib + supabase-py), Supabase smokin-ops project (`xuvdcygqyuajtlpavafr`, schemas `eval` + `build`), Next.js 14 on Vercel, GitHub Actions for cron, existing cc-analytics CLI for cost rows.

**Done Criteria (operator-graded at Phase 3 close):**
1. `eval.sessions` table exists on smokin-ops, populated with ≥14 rows
2. `eval.runs` table exists with one row per harness run, FK to `eval.sessions`
3. `examples/evals/run_harness.py` runs end-to-end against the 14-day window with no manual edits and exits 0
4. Output matches a manually-graded gold-set of 3 sessions (drift < 10% per metric)
5. `aof-eval.vercel.app` returns 200 with at least 1 chart populated
6. GitHub Actions workflow `aof-eval-weekly.yml` runs on Sun 10am cron and writes a new `eval.runs` row
7. README in `m9751/agent-operating-framework` links to aof-eval.vercel.app
8. `build.deliverables` row inserted on smokin-ops with title "AOF Eval Harness v1" + URL

---

## File Structure

**Schema (smokin-ops, via PR + Supabase Branching — never `apply_migration` MCP):**
- `m9751/smokin-ops/supabase/migrations/<ts>_eval_sessions.sql`
- `m9751/smokin-ops/supabase/migrations/<ts>_eval_runs.sql`

**Harness (m9751/agent-operating-framework):**
- `examples/evals/README.md`
- `examples/evals/run_harness.py`
- `examples/evals/graders/{__init__,rule_adherence,plan_delivery_gap,cost,dispatch_quality}.py`
- `examples/evals/lib/{handoff_parser,supabase_client}.py`
- `examples/evals/tests/{test_handoff_parser,test_rule_adherence,test_plan_delivery_gap}.py`
- `examples/evals/tests/fixtures/{handoff_complete.md,handoff_partial.md,gold_set.md}`
- `.github/workflows/aof-eval-weekly.yml`

**Dashboard (new repo: m9751/aof-eval):**
- `app/page.tsx`, `app/api/runs/route.ts`, `app/api/sessions/route.ts`
- `lib/supabase.ts`
- `components/{RuleAdherenceChart,CostTrendChart,SessionTable}.tsx`

---

## Phase 0: Baseline (manual, no code)

### Task 0.1: Inventory the 14-day window
- [ ] List handoffs: `find ~/Documents/SmokinTerritory/SmokinTerritory/03-Projects/ST2/ -name "handoff-*.md" -mtime -14 | sort > /tmp/aof-eval-window.txt && wc -l /tmp/aof-eval-window.txt` (expect ≥14)
- [ ] Spot-check 3 handoffs for Done Criteria sections
- [ ] Record baseline counts to `~/Documents/SmokinTerritory/SmokinTerritory/03-Projects/ST2/aof-eval-baseline.md`

### Task 0.2: Hand-grade gold-set of 3 sessions
- [ ] Pick 3 sessions (clean / gap-logged / no-DC) — record paths
- [ ] Score each on 4 metrics (rule adherence, plan→delivery, cost, dispatch) 0–10
- [ ] Write YAML to `examples/evals/tests/fixtures/gold_set.md`
- [ ] Commit on branch `aof-eval-harness-v1`

---

## Phase 1: Schema on smokin-ops (PR + Supabase Branching)

**Hard rule:** PR workflow on `m9751/smokin-ops`. Never `apply_migration` MCP.

### Task 1.1: eval.sessions migration
- [ ] Clone smokin-ops, branch `aof-eval-schema-20260511`
- [ ] Write `<ts>_eval_sessions.sql`:
```sql
CREATE SCHEMA IF NOT EXISTS eval;
CREATE TABLE IF NOT EXISTS eval.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_date date NOT NULL,
  handoff_path text NOT NULL,
  machine text NOT NULL CHECK (machine IN ('mac','win','unknown')),
  rule_adherence_score numeric,
  rule_adherence_evidence jsonb,
  plan_delivery_score numeric,
  plan_delivery_evidence jsonb,
  session_cost_usd numeric,
  session_tokens_input bigint,
  session_tokens_output bigint,
  dispatch_score numeric,
  dispatch_evidence jsonb,
  composite_score numeric,
  created_at timestamptz NOT NULL DEFAULT now(),
  run_id uuid
);
CREATE INDEX IF NOT EXISTS eval_sessions_session_date_idx ON eval.sessions(session_date DESC);
CREATE INDEX IF NOT EXISTS eval_sessions_run_id_idx ON eval.sessions(run_id);
ALTER TABLE eval.sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon read eval sessions" ON eval.sessions FOR SELECT USING (true);
```
- [ ] Commit + push

### Task 1.2: eval.runs migration
- [ ] Write `<ts>_eval_runs.sql`:
```sql
CREATE TABLE IF NOT EXISTS eval.runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_ts timestamptz NOT NULL DEFAULT now(),
  window_start date NOT NULL,
  window_end date NOT NULL,
  sessions_graded int NOT NULL,
  mean_rule_adherence numeric,
  mean_plan_delivery numeric,
  mean_composite numeric,
  total_cost_usd numeric,
  total_tokens bigint,
  harness_version text NOT NULL,
  aof_version text NOT NULL,
  trigger_kind text NOT NULL CHECK (trigger_kind IN ('manual','cron','backfill')),
  github_run_id text,
  notes text
);
CREATE INDEX IF NOT EXISTS eval_runs_run_ts_idx ON eval.runs(run_ts DESC);
ALTER TABLE eval.runs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon read eval runs" ON eval.runs FOR SELECT USING (true);
ALTER TABLE eval.sessions ADD CONSTRAINT eval_sessions_run_id_fkey
  FOREIGN KEY (run_id) REFERENCES eval.runs(id) ON DELETE SET NULL;
```
- [ ] Commit + push

### Task 1.3: Open PR, verify Supabase Preview, merge
- [ ] `gh pr create` (title: feat(eval): AOF eval harness schema)
- [ ] Wait for `supabase-preview` CI green
- [ ] Verify schema via `list_tables` MCP on preview project_id
- [ ] `gh pr merge --squash --delete-branch`

---

## Phase 2: Harness scaffolding (Python, TDD)

Branch `aof-eval-harness-v1` in `~/repos/agent-operating-framework/`.

### Task 2.1: Handoff parser (TDD)
- [ ] Create `examples/evals/lib/__init__.py`, `examples/evals/tests/__init__.py`, fixtures `handoff_complete.md` + `handoff_partial.md`
- [ ] Write failing test `test_handoff_parser.py` (3 cases: complete, partial, dc-counts)
- [ ] Implement `lib/handoff_parser.py` (frontmatter regex + Done Criteria extraction with ✅/❌ markers, returns `Handoff` dataclass with `dc_met_count()` / `dc_total_count()`)
- [ ] Tests pass
- [ ] Commit

### Task 2.2: Rule adherence grader (TDD)
- [ ] Write failing test `test_rule_adherence.py` (clean scores ≥9.0, partial < 9.0)
- [ ] Implement `graders/rule_adherence.py` — penalties: blocked_by_gate 1.5, errors_section_nonempty 1.0, dc_partial 0.5; returns `(score: float, evidence: dict)`
- [ ] Tests pass
- [ ] Commit

### Task 2.3: Plan-delivery gap grader (TDD)
- [ ] Write failing test `test_plan_delivery_gap.py` (all-met = 10.0, zero-met = 0.0, no-DC = None)
- [ ] Implement `graders/plan_delivery_gap.py` — `score = 10 * met/total`, returns `(Optional[float], evidence)`
- [ ] Tests pass
- [ ] Commit

### Task 2.4: Cost + dispatch graders (no TDD, thin)
- [ ] Implement `graders/cost.py` — reads from handoff frontmatter
- [ ] Implement `graders/dispatch_quality.py` — v1 stub returns `(None, {"note": "v1 stub..."})`
- [ ] Commit

### Task 2.5: Supabase client + CLI
- [ ] Implement `lib/supabase_client.py` — `insert_run()` + `insert_session()` against `eval` schema
- [ ] Implement `run_harness.py` — argparse (--window-days, --trigger, --github-run-id, --aof-version, --handoff-dir, --dry-run); walks handoffs in window; grades; prints summary; if not dry-run, writes
- [ ] Composite score: `0.6 * rule + 0.4 * plan` (or just rule if plan is None)
- [ ] Write `examples/evals/README.md`
- [ ] Dry-run against 14-day window — verify ≥5 sessions graded, no exceptions
- [ ] Compare against gold-set, drift < 10% per metric (else debug grader constants)
- [ ] Commit

---

## Phase 3: First production run + self-application

### Task 3.1: Configure + backfill
- [ ] Get `service_role` key for smokin-ops from Supabase dashboard
- [ ] `export SMOKIN_OPS_URL=https://xuvdcygqyuajtlpavafr.supabase.co` + service key
- [ ] `pip install --user supabase==2.6.0`
- [ ] `python -m examples.evals.run_harness --window-days 14 --trigger backfill`
- [ ] Verify via MCP `execute_sql`: `eval.sessions` count ≥14, `eval.runs` count = 1

### Task 3.2: Log to build.deliverables
- [ ] Insert via MCP:
```sql
INSERT INTO build.deliverables (title, description, status, build_state, project, repo, metadata)
VALUES ('AOF Eval Harness v1', '...', 'shipped', 'verified', 'agent-operating-framework',
        'm9751/agent-operating-framework', jsonb_build_object('phase','first-run-complete'))
RETURNING id;
```

### Task 3.3: Phase 3 close — diff promises vs delivery
- [ ] Walk Done Criteria 1–8, mark ✅/❌/⚠️ to handoff at `03-Projects/ST2/handoff-mac-YYYYMMDD-aof-eval-phase3.md`
- [ ] `git push -u origin aof-eval-harness-v1`

---

## Phase 4: Dashboard (new Vercel project)

### Task 4.1: Bootstrap m9751/aof-eval
- [ ] `mkdir ~/repos/aof-eval && cd && gh repo create m9751/aof-eval --public --source=. --remote=origin`
- [ ] `npx create-next-app@14 . --typescript --app --tailwind --no-src-dir --import-alias "@/*" --no-eslint`
- [ ] `npm install @supabase/supabase-js recharts`
- [ ] Initial commit + push

### Task 4.2: Supabase client + API routes
- [ ] `lib/supabase.ts` — anon client, `db.schema: "eval"`
- [ ] `app/api/runs/route.ts` — GET 20 most recent runs
- [ ] `app/api/sessions/route.ts` — GET sessions from last 14 days
- [ ] Commit

### Task 4.3: Dashboard page + components
- [ ] `components/RuleAdherenceChart.tsx` (recharts LineChart, domain 0–10)
- [ ] `components/CostTrendChart.tsx` (recharts BarChart)
- [ ] `components/SessionTable.tsx` (date / machine / rule / plan / cost / composite)
- [ ] `app/page.tsx` — server component, fetches both APIs, renders stats + 2 charts + table
- [ ] Commit + push

### Task 4.4: Deploy
- [ ] Import to Vercel, env vars `NEXT_PUBLIC_SMOKIN_OPS_URL` + `NEXT_PUBLIC_SMOKIN_OPS_ANON_KEY`
- [ ] `curl` 200 check on `https://aof-eval.vercel.app/`
- [ ] If 401, disable Deployment Protection
- [ ] Update `build.deliverables` row with URL

---

## Phase 5: Weekly cron + README link

### Task 5.1: GitHub Actions weekly workflow
- [ ] Write `.github/workflows/aof-eval-weekly.yml` — cron `0 14 * * 0` (Sun 10am ET), workflow_dispatch enabled
- [ ] **Resolve handoff store** (decision point): mirror to private `m9751/handoff-store` repo (recommended) or push to Supabase storage bucket
- [ ] Set repo secrets: `SMOKIN_OPS_URL`, `SMOKIN_OPS_SERVICE_KEY`, `HANDOFF_STORE_PAT`
- [ ] `gh workflow run aof-eval-weekly.yml` + `gh run watch` — verify success, new `eval.runs` row with `trigger_kind='cron'`
- [ ] Commit

### Task 5.2: README badge + cross-link
- [ ] Insert "Self-Applied Measurement" block in `README.md` linking to aof-eval.vercel.app
- [ ] Commit + push

### Task 5.3: Final close
- [ ] Walk all 8 Done Criteria, mark status in `handoff-mac-YYYYMMDD-aof-eval-shipped.md`
- [ ] Update MEMORY.md (replace "AOF EVAL HARNESS NEXT" entry, add `"check aof eval"` trigger)
- [ ] Update `build.deliverables` row to `build_state='verified'`
- [ ] Open PR on `m9751/agent-operating-framework`

---

## Self-Review

**Coverage:** all 4 metrics, self-application, smokin-ops persistence, Vercel dashboard, weekly cron, no `apply_migration`.

**Open risk (Phase 5 Step 2):** GitHub Actions can't reach iCloud handoffs. Decision point in plan, not a blocker for Phases 0–4.

**Dispatch grader is v1 stub** — documented limitation, deferred until hook log integration.
