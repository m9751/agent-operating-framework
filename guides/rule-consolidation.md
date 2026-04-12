# Rule Consolidation: From 24 Rules to 6

> You started with 1 rule. Four weeks later you have 24. Each one was born from a real incident. But 24 rules stuffed into the agent's context window means paradoxically worse compliance — there's too much to follow.

## The Problem: Rule Bloat

Every rule I wrote was justified. An agent guessed a column name instead of checking the schema — I wrote a "no guessing" rule. It recommended CLI commands without verifying them — I wrote a "verify CLI commands" rule. It kept retrying a broken approach — I wrote a "three-failure stop" rule.

Each rule was a reasonable response to a specific failure. But rules accumulate faster than they get cleaned up:

- **Week 1:** 3 rules. Agent reads them all. Compliance is high.
- **Week 2:** 8 rules. Still manageable. A few get skipped under pressure.
- **Week 3:** 16 rules. The agent loads them all at session start but can't hold them all in active attention. Compliance drops to maybe 60%.
- **Week 4:** 24 rules. Some rules contradict each other. The agent spends tokens re-reading instructions instead of doing work. Compliance is worse than week 1.

The irony: more rules meant less discipline, not more. The context window has a carrying capacity for instructions, and I'd blown past it.

## The Pattern: Shared Root Causes

When I laid all 24 rules side by side, a pattern jumped out. Many rules that looked different were actually the same rule wearing different clothes:

| Rule name | What it said |
|---|---|
| Read before acting | Check current state before modifying anything |
| No guessing | Don't guess column names, CLI flags, or config values |
| Verify CLI commands | Run `--help` before recommending commands |
| Evidence-based action | Present an evidence card before non-trivial actions |
| Three-failure stop | Stop after 3 failures and research instead |
| Process before execution | Follow the checklist, even when it feels slow |

Six rules. One root cause: **don't act without evidence.**

The same clustering appeared elsewhere:

- "Feature freeze on working code," "approved stack only," "search the ecosystem before building," and "use the platform you're selling" were all **scope discipline** — don't add complexity beyond what was asked.
- "Deploy workflow," "post-delivery checklist," "file destination rules," and "HTML optimization" were all **delivery protocol** — one workflow for shipping anything.
- "Session open items," "plan mode exit," and "post-session audit" were all **session lifecycle** — how a session starts, executes, and closes.

Four clusters. Four root causes. Twenty-four rules collapsed to the essentials.

## The Method

### Step 1: Cluster by root cause

Spread every rule out. Ignore the titles — read the "why" section of each one. Group rules that exist because of the same underlying failure mode.

The question to ask: "If the agent had followed Rule X perfectly, would Rule Y have been unnecessary?" If yes, they belong in the same cluster.

### Step 2: Write one summary rule per cluster

Each summary rule should be:

- **Under 40 lines.** If the agent can't hold it in attention, it doesn't exist.
- **4 gates maximum.** More than 4 decision points and the agent starts skipping them.
- **Action-oriented.** "Read the thing before touching it" beats "ensure comprehensive verification of current state prior to modification."
- **Self-testing.** Include a one-line test: "If the answer to 'why did you do that?' starts with 'I assumed...' — this rule was skipped."

### Step 3: Move detail to reference files

The full incident history, the edge cases, the expanded explanations — these don't need to live in the always-loaded context. Move them to a `references/` directory that the agent loads on demand.

Structure:
```
rules/
  read-before-acting.md      # 30 lines, always loaded
  scope-discipline.md         # 35 lines, always loaded
  delivery-protocol.md        # 38 lines, always loaded
  session-lifecycle.md        # 32 lines, always loaded
references/
  read-before-acting-details.md   # Full prose, all incidents, loaded on demand
  scope-discipline-details.md     # Full Forced Pause procedure, Exchange search protocol
  delivery-protocol-details.md    # 5-question pre-build gate, verification commands
  session-lifecycle-details.md    # 10-item closing checklist, handoff format spec
```

The summary rule is the law. The detail file is the case law. Both exist, but only the law needs to be in the courtroom at all times.

### Step 4: Archive the originals

Don't delete the old rules. Move them to an `archived/` directory with a mapping document that traces every old rule to its new home. You may need to roll back, and you will definitely need to prove that no lesson was lost.

The mapping should answer: "Where did the content from `verify-cli-commands.md` go?" Answer: "Gate 3 of `read-before-acting.md` (summary) + the CLI verification section of `references/read-before-acting-details.md` (detail)."

## Results

After consolidation:

| Metric | Before | After |
|---|---|---|
| Rule count | 24 | 6 |
| Max lines per rule | 120+ | 40 |
| Total context consumed by rules | ~3,000 lines | ~200 lines |
| Compliance (subjective) | ~60% | Noticeably higher |

The agent could actually hold 6 rules in attention. It stopped skipping steps — not because the rules were stricter, but because there were few enough to follow.

## When NOT to Consolidate

Not every rule belongs in a cluster:

- **Rules under 30 lines that stand alone.** If a rule is already short and covers a unique failure mode, leave it. Consolidation has overhead — don't do it for cosmetic reasons.
- **Rules with genuinely different root causes.** "No local infrastructure" (don't build things that depend on a laptop being on) and "secure configuration" (don't expose secrets) look related but aren't. Forcing them together creates a confusing hybrid.
- **Rules you wrote this week.** New rules need time to prove themselves. Consolidate after you've seen a rule invoked (or violated) at least 3 times. Premature consolidation hides lessons that haven't fully crystallized.

The test: if you can't name the shared root cause in one sentence, they don't belong together.

## The Consolidation Is a Deliverable

Treat the consolidation itself as tracked work:

1. **Create a mapping document.** Every old rule maps to its new location. Every "Why" line from every archived rule is preserved in a detail file.
2. **Update cross-references.** If hooks, skills, or other config files pointed to old rule paths, update them. Stale pointers are silent failures.
3. **Back up before starting.** Take a snapshot of the entire rules directory. If the consolidation goes wrong, you need a clean rollback path.
4. **Test the result.** Start a fresh session after consolidation. Does the agent load the new rules? Does it follow them? Are there gaps where a lesson was lost?

## The Lifecycle of a Lesson

Rules aren't static. They have a lifecycle:

```
Incident → Feedback note (advice)
  → If ignored twice: Rule (law)
    → If ignored again: Hook (automated barrier)
      → If multiple rules share root cause: Consolidation
        → Summary rule (always loaded) + Detail file (on demand)
```

Consolidation isn't the end. It's maintenance. The rules will grow again as new incidents happen. When they reach the carrying capacity of your context window — consolidate again.

The goal isn't zero rules. It's the minimum number of rules that encode the maximum number of lessons.
