# From Beginner to Framework

> You've set up CLAUDE.md. You've created a few skills. Outputs are still inconsistent. Here's why — and here's what to do about it.

## The Wall

Most people who learn Claude Code follow the same path:

1. Install Claude Code
2. Create a CLAUDE.md with identity, tone, and output format
3. Build a few skills for repeated tasks
4. Use Projects Memory to persist context across sessions

This works well at first. Then it stops working.

The symptoms:
- The agent follows your rules sometimes but not always
- Output quality drifts between sessions
- The same mistakes happen again despite being "fixed" in the prompt
- You're manually reviewing every output — the skills aren't reliable enough to trust
- You keep re-explaining things you thought were already settled

## Why It Happens

The beginner guides teach you to write **advice**. They tell you to define your role, set quality rules, and structure your output. That's necessary — but it's only the first layer.

Advice gets ignored under pressure. When the agent is deep in a multi-step task, it forgets the rules in your CLAUDE.md. When context gets compressed, soft guidance is the first thing to go. When the task feels simple, the agent skips the process because "it's faster to just do it."

The issue isn't your CLAUDE.md. The issue is that your CLAUDE.md has no enforcement mechanism.

## The Three Layers

This framework adds two layers that most beginner guides never mention:

```
Layer 1: Advice    → CLAUDE.md, memory files     (what most guides teach)
Layer 2: Law       → Rule files in ~/.claude/rules/   (hard constraints)
Layer 3: Barriers  → Hooks that block tool calls  (automated enforcement)
```

**Layer 1 (Advice)** is your CLAUDE.md. It defines identity, output contracts, quality criteria. The agent reads it. The agent can ignore it.

**Layer 2 (Law)** is rule files. They're loaded with higher priority than memory. They use explicit "MANDATORY" framing. The agent is much less likely to ignore them — but technically still can.

**Layer 3 (Barriers)** is hooks. They fire before or after tool execution. If a hook returns an error, the tool call is blocked. The agent cannot bypass them.

Most people never get past Layer 1. That's why their CLAUDE.md "stops working" — it never had teeth.

## The Escalation Principle

You don't need all three layers on day one. Start with advice. Escalate when it fails:

```
Mistake happens once     → write a memory entry (advice)
Same mistake happens twice → promote to a rule (law)
Rule gets ignored         → promote to a hook (barrier)
```

This is documented in detail in the [Enforcement Architecture guide](enforcement-architecture.md).

## What This Framework Adds

If you've completed the beginner path (CLAUDE.md + skills + memory), this framework gives you:

| What you have | What this adds | Guide |
|--------------|---------------|-------|
| CLAUDE.md with identity and rules | **Section 0: Project Identity** — structured role, output contract, quality criteria, session lifecycle, communication standards | [AGENT_FRAMEWORK.md](../AGENT_FRAMEWORK.md) |
| Skills that work most of the time | **Auto-optimization** — eval-driven improvement with guardrails, triage (which skills can be auto-iterated vs. which need human review) | [Auto-Optimizing Skills](auto-optimization.md) |
| Memory that persists across sessions | **Enforcement architecture** — escalation from memory to rules to hooks when advice gets ignored | [Enforcement Architecture](enforcement-architecture.md) |
| Manual output review | **Quality gates** — verification before done, post-delivery checklist, staff-engineer test | [AGENT_FRAMEWORK.md](../AGENT_FRAMEWORK.md) Section 4 |
| Hope that the agent reads the file before acting | **Read Before Acting rule** — 4-gate universal rule that forces evidence before action | [read-before-acting.md](../examples/claude-code-rules/read-before-acting.md) |
| No circuit breakers | **Three-Failure Stop** — agent stops after 3 failures instead of brute-forcing | [three-failure-stop.md](../examples/claude-code-rules/three-failure-stop.md) |

## Where to Start

Don't adopt everything. Start with the rule that matches your biggest pain:

1. **Agent keeps guessing instead of reading** → copy [read-before-acting.md](../examples/claude-code-rules/read-before-acting.md) to `~/.claude/rules/`
2. **Agent over-engineers or adds unrequested features** → copy [scope-control.md](../examples/claude-code-rules/scope-control.md) to `~/.claude/rules/`
3. **Agent brute-forces failures** → copy [three-failure-stop.md](../examples/claude-code-rules/three-failure-stop.md) to `~/.claude/rules/`
4. **Sessions start cold** → copy [session-lifecycle.md](../examples/claude-code-rules/session-lifecycle.md) to `~/.claude/rules/`
5. **Ready for the full system** → copy [AGENT_FRAMEWORK.md](../AGENT_FRAMEWORK.md) as your project's `CLAUDE.md`

Then, when something breaks, write the rule. Include the date and the cost. That's how every rule in this framework was born.
