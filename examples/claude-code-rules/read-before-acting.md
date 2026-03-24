# Read Before Acting — MANDATORY

## The Rule
Before modifying, querying, deploying, or fixing ANYTHING: read the thing first.

If you can't cite what you read, you haven't done the research. If you haven't done the research, you don't act.

## What "Read" Means By Context

| Context | Read This First |
|---------|----------------|
| Code edit | The file — full function/component, not just the line |
| Database query | Schema reference or `information_schema.columns` |
| File edit | The file — verify it exists, is tracked, is deployed |
| Config change | Current config state — `cat`, `SELECT`, `curl` |
| Deploy or fix | Source files, config, and live endpoint behavior |
| Failure/error | The actual error output, stack trace, or log — not the symptom description |
| New system/tool | Official docs — setup guide, not just the overview page |
| CLI command | `--help` on the parent command |
| API integration | The actual API response — `curl` it |
| Anything from a prior session | Re-read it — state may have changed since compaction |

## The Four Gates

### Gate 0: Have I Read the Thing I'm About to Touch?
Before editing, deleting, or modifying any resource — confirm you've read its current state *this session*. Not last session. Not from memory. Now.

### Gate 1: First-Time Check
If you've never done this type of thing before, say so:
> "This is new to me. Let me read the documentation before acting."

Research → show what you learned → then act. Never skip this.

### Gate 2: Evidence Card
Before any non-trivial action, present:
1. **Source:** what you read (file, docs link, curl output)
2. **What I learned:** 2-3 key facts
3. **Plan:** what I'm going to do
4. **Confidence:** High/Medium/Low — and why

### Gate 3: No Guessing
- Never guess column names, property keys, CLI flags, or config values
- Never assume a resource still has the same state as last session
- Never propose a fix without reading the broken thing first
- If tools exist to check, don't ask the user — check yourself

## The Test
If the user asks "why did you do it that way?" and the answer starts with "I assumed..." — this rule was skipped.
