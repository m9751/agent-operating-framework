# Read Before Acting — MANDATORY

## The Rule
Before modifying, querying, deploying, or fixing anything: read the thing first. If you can't cite what you read in **this session**, you haven't done the research. If you haven't done the research, you don't act.

## The Four Gates

**Gate 0 — Read before touching.** Confirm you've read the resource's current state *this session*. Not last session. Not from memory. Now.

**Gate 1 — First-time check.** If you've never done this type of thing before, say so: "This is new to me. Let me read the docs before acting." Research → show what you learned → then act.

**Gate 2 — Evidence card.** Before any non-trivial action, present: **Source** (what you read), **What I learned** (2–3 facts), **Plan** (what you'll do), **Confidence** (High/Med/Low). Low = ask. Medium = flag. High = cite.

**Gate 3 — No guessing.** Never guess column names, property keys, CLI flags, config values, or filenames. If a tool exists to check (`--help`, `information_schema.columns`, `curl`, `ls`), use it — don't ask the user.

## Escalation: Three-Failure Stop
If the same task fails 3 times, halt. Say out loud: "This has failed 3 times. I don't understand this system well enough." State what you tried and why each attempt failed. Do not try a 4th variation. Research, then retry with evidence.

## The Test
If the answer to "why did you do it that way?" starts with "I assumed..." — this rule was skipped.

## Why
This rule absorbs 6 prior rules that all traced to the same root cause: acting without reading. Representative incidents:
- Entire session on wrong hypothesis. Reading 43 lines of config found the real problem in 2 minutes.
- 5+ failed queries on columns that don't exist. Schema was in the database the whole time.
- Failed 5+ times on one task. Answer found in 5 minutes of doc reading.
- Recommended install commands from a README without verifying them. Wrong syntax.
- Edited a file that wasn't tracked in git. Cost a full edit cycle.

## Enforcement
This rule can be enforced with a `PreToolUse` hook that blocks writes to infrastructure resources (database views, edge functions, config files) unless the agent has logged a prior read of the target resource in the same session. See `examples/hooks/read-gate.sh` for a working example.
