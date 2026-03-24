# Why Post-Failure Frameworks Beat Pre-Failure Frameworks

> Most CLAUDE.md guides tell you what to write before anything goes wrong. This framework was written after things went wrong. Here's why that matters.

## Two Types of Agent Frameworks

**Pre-failure frameworks** define ideal behavior upfront:
- "Be clear and concise"
- "Use concrete examples"
- "Follow the project's coding style"

**Post-failure frameworks** encode the cost of specific mistakes:
- "Read the config file before deploying — because guessing the port cost 8 hours on 2026-03-21"
- "Stop after 3 failures — because 5+ retries at 11pm burned an entire session on the wrong hypothesis"
- "Check what depends on a file before deleting it — because removing a function broke 3 downstream imports"

## Why Post-Failure Rules Stick

A pre-failure rule says: "Be careful when deploying."
A post-failure rule says: "Read config.properties, verify http.port=8081, check for duplicate HTTP listeners. Why: wrong port + second listener crashed CloudHub. Cost: 10 rapid deploy cycles, 8 hours wasted."

The difference:
- **Specificity.** Post-failure rules name the exact action, the exact check, the exact failure mode.
- **Cost.** Every rule carries the weight of a real incident. The agent (and the human) can feel why it matters.
- **Testability.** "Did I read config.properties?" is testable. "Was I careful?" is not.

## The Incident Report Pattern

Every rule in this framework includes:

```markdown
## Why This Exists
[Date]: [What happened]. [What it cost]. [What would have prevented it].
```

This isn't documentation for documentation's sake. It's the mechanism that makes the rule durable. When the agent (or a future teammate) reads "this cost 8 hours," they don't skip the rule.

## How to Build Your Own Post-Failure Framework

1. **Don't write rules on day one.** Start with the bare framework and a blank CLAUDE.md.
2. **When something breaks, write the rule.** Include the date, the cost, and the prevention.
3. **When a rule gets ignored, escalate it.** Memory → Rule → Hook.
4. **Consolidate periodically.** Three rules with the same root cause become one rule with three incidents.

The framework grows organically from your actual failure modes — not from a generic best-practices list.

## Pre-Failure Rules Still Have a Place

Section 0 (Project Identity) is a pre-failure section. You define your role, output contract, and quality criteria before anything goes wrong. That's appropriate — it's foundational context, not behavioral enforcement.

The distinction: **Section 0 defines what good looks like. Sections 1-7 prevent what bad looks like.** Both are necessary. But the enforcement sections only earn their weight when they carry real incident data.
