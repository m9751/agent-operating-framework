# Auto-Optimizing Agent Skills

> How to close the loop between "score the output" and "improve the prompt" — without overfitting.

## The Problem

You have a skill that works 70% of the time. You've written evals. You know what "good" looks like. But improving the skill is manual: read the failures, guess what to change, edit the prompt, re-run, check again.

The question: can you automate the iteration loop — let the agent modify its own skill prompts based on eval scores?

The answer: **yes, but only for certain skills, and only with guardrails.**

## The Triage: Which Skills Can Be Auto-Optimized?

Not all skills benefit from automated iteration. The key question: **can an automated judge reliably score the output?**

| Skill type | Auto-iteration viable? | Why |
|-----------|----------------------|-----|
| Template-based (email campaigns, report generators) | **Yes** | Structural: required sections, format compliance, data presence |
| Data transformation (scoring dashboards, CSV generators) | **Yes** | Verifiable: data accuracy, chart presence, correct calculations |
| Content generation (LinkedIn posts, articles) | **Partial** | Structure yes, voice/resonance no |
| Research and analysis (competitive intel, account research) | **No** | Judgment quality, factual accuracy, relevance — can't auto-judge |
| Architecture and design (solution blueprints, system design) | **No** | Architectural fitness, customer-specific reasoning — can't auto-judge |
| Signal interpretation (alert triage, anomaly investigation) | **No** | Signal relevance, recommendation quality — can't auto-judge |

**Rule of thumb:** If the eval measures *format* (sections, structure, required elements), auto-iterate. If the eval measures *judgment* (accuracy, relevance, insight quality), human-review only.

## The Method

### Phase 1: Validate Your Judges First

Before auto-iterating, verify your evals actually measure what matters:

1. Run the skill 20+ times manually
2. Score each output yourself (human ground truth)
3. Run your automated judge on the same outputs
4. Calculate True Positive Rate and True Negative Rate
5. **Only proceed if both TPR and TNR > 90%**

If your judge says "pass" when a human says "fail" (low TNR), auto-iteration will optimize toward outputs that fool the judge but disappoint the human. This is the #1 failure mode.

### Phase 2: The Iteration Loop

```
1. Run eval (baseline score)
2. If score < threshold:
   a. Feed failures + current skill prompt to the agent
   b. Ask: "What specific change would fix these failures?"
   c. Apply the change to a git branch
   d. Re-run eval on the branch
   e. If score improved AND no regression: merge
   f. If score dropped OR regression detected: discard
3. Log the iteration
4. Repeat until stopping condition
```

### Phase 3: Cross-Skill Regression

After optimizing one skill, run benchmarks on skills that depend on it. A change to one skill's prompt can break handoff contracts with other skills.

```
Optimize skill A → re-run evals for skills B, C that depend on A
If B or C regressed: revert the change to A
```

## The Seven Guardrails

These prevent auto-iteration from making things worse:

### 1. Triage before optimizing
Classify each skill as auto-iterable or human-review-only (see triage table above). Never auto-iterate judgment-heavy skills.

### 2. Validate judges first
TPR/TNR > 90% on human-scored ground truth before the loop starts. If judges are unreliable, you're optimizing toward garbage.

### 3. Define regression threshold
Score drops by more than 3% from baseline = automatic revert. Don't let the optimizer chase one improvement while degrading elsewhere.

### 4. Set a cost cap
Define maximum API spend per optimization run (e.g., $5). Each iteration burns calls — especially with large models. Without a cap, a stuck loop can burn real money.

### 5. Human spot-check every N iterations
Not fully unattended. Every 3 iterations, a human reviews the latest output. The eval catches format failures. The human catches judgment failures the eval can't see.

### 6. Cross-skill regression suite
After optimizing one skill, run benchmarks on dependent skills. Revert if any dependent skill regressed. (See Phase 3 above.)

### 7. Define a stopping condition
Halt after 3 consecutive iterations with less than 2% improvement. Without this, the loop either runs forever or gets killed arbitrarily.

## Data Model

Track optimization history in your database of choice. The schema below is backend-agnostic:

### optimization_runs
One row per optimization session.

| Column | Type | Description |
|--------|------|-------------|
| run_id | uuid | Primary key |
| skill_name | text | Which skill was optimized |
| trigger | text | manual / scheduled |
| started_at | timestamp | When the run began |
| completed_at | timestamp | When it finished |
| initial_score | numeric | Score before optimization |
| final_score | numeric | Score after optimization |
| iterations_count | integer | How many iterations ran |
| total_cost_usd | numeric | Total API cost |
| status | text | running / completed / stopped / reverted |
| stopping_reason | text | converged / cost_cap / manual_stop / regression |
| git_branch | text | Branch where changes were made |
| git_commit_before | text | Commit hash before changes |
| git_commit_after | text | Commit hash after changes |

### optimization_iterations
One row per iteration within a run.

| Column | Type | Description |
|--------|------|-------------|
| iteration_id | uuid | Primary key |
| run_id | uuid | FK to optimization_runs |
| iteration_number | integer | 1, 2, 3... |
| score_before | numeric | Score entering this iteration |
| score_after | numeric | Score after this iteration |
| score_delta_pct | numeric | Percentage change |
| diff_summary | text | What changed in the skill prompt |
| decision | text | kept / discarded / reverted |
| cost_usd | numeric | API cost for this iteration |
| failure_modes_detected | jsonb | What the eval flagged |
| change_rationale | text | Why the optimizer proposed this change |

### optimization_cross_checks
Cross-skill regression results.

| Column | Type | Description |
|--------|------|-------------|
| check_id | uuid | Primary key |
| run_id | uuid | FK to optimization_runs |
| dependent_skill_name | text | Skill that was regression-tested |
| score_before | numeric | Dependent skill's score before |
| score_after | numeric | Dependent skill's score after |
| regressed | boolean | True if score dropped > threshold |

### eval_judges
Judge validation metadata.

| Column | Type | Description |
|--------|------|-------------|
| judge_id | uuid | Primary key |
| skill_name | text | Which skill this judge evaluates |
| judge_type | text | format / content / judgment |
| tpr | numeric | True Positive Rate |
| tnr | numeric | True Negative Rate |
| validated_at | timestamp | When validation was run |
| sample_size | integer | Number of samples used |
| viable_for_auto | boolean | TPR and TNR both > 90% |

## Existing Tools

Two open-source repos implement the iteration loop for Claude Code skills:

| Repo | What it does | Strength | Limitation |
|------|-------------|----------|------------|
| [autorefine-skill-improvement](https://github.com/surahli123/autorefine-skill-improvement) | Forces judge validation before mutation loop | Methodologically rigorous | Time-intensive (60-90 min per run) |
| [claude-skill-prompt-optimizer](https://github.com/bergr7/claude-skill-prompt-optimizer) | Diagnose → edit → verify loop | Simpler, faster | No judge validation phase |

Both are early-stage (4 stars each, Feb 2026). The guardrails in this guide apply regardless of which tool you use — or if you build your own.

For eval-only (scoring without auto-iteration), [PromptFoo](https://github.com/promptfoo/promptfoo) (18K stars) is production-grade and supports Claude natively.

## What This Doesn't Solve

Auto-iteration improves skills that fail on **format** — missing sections, wrong structure, inconsistent templates.

It cannot improve skills that fail on **judgment** — wrong analysis, bad recommendations, inaccurate research. For those, the improvement loop is: human reads the output → human identifies the failure → human edits the skill prompt → human verifies. There is no shortcut.

The triage step exists to prevent you from auto-optimizing skills where the eval can't measure what actually matters.
