# Agent Operating Framework

A battle-tested operating framework for AI coding agents — born from production failures, not theory.

## Who This Is For

You've set up CLAUDE.md. You've built a few skills. You're using Projects Memory. But outputs are still inconsistent, the agent ignores rules under pressure, and you're manually reviewing everything.

This framework is the next step. It adds enforcement (rules that can't be ignored), circuit breakers (stop after 3 failures), and an escalation model (advice → law → barriers) that makes your CLAUDE.md actually stick.

If you're just getting started with Claude Code, read the beginner guides first. If you've hit the wall where your CLAUDE.md "stops working," [start here](guides/from-beginner-to-framework.md).

## What This Is

A behavioral operating system that makes AI coding agents (Claude Code, Cursor, Copilot, etc.) more reliable. It combines:

- **Project identity** — role, output contracts, quality criteria, session lifecycle
- **Evidence-first culture** — read before acting, show research, no guessing
- **Circuit breakers** — three-failure stop, scope control, collaboration model
- **Quality gates** — verification before done, post-delivery checklist
- **Self-improvement** — capture lessons, enforce with memory → rules → hooks
- **Auto-optimization** — eval-driven skill improvement with guardrails

Every rule exists because its absence caused a specific, documented failure.

## Quick Start

Copy `AGENT_FRAMEWORK.md` to your project root as `CLAUDE.md`. Fill in Section 0 with your project specifics. Start a session.

```bash
cp AGENT_FRAMEWORK.md /path/to/your/project/CLAUDE.md
```

See [guides/getting-started.md](guides/getting-started.md) for the full adoption path.

## Library Contents

### The Framework
- **[AGENT_FRAMEWORK.md](AGENT_FRAMEWORK.md)** — The complete framework (v1.1). Use as your project's CLAUDE.md.

### Guides
- **[From Beginner to Framework](guides/from-beginner-to-framework.md)** — You've built CLAUDE.md and skills but outputs are inconsistent. Here's why and what to do next.
- **[Getting Started](guides/getting-started.md)** — How to adopt the framework, where files go, recommended path
- **[Enforcement Architecture](guides/enforcement-architecture.md)** — Memory → Rules → Hooks escalation model with examples
- **[Why Post-Failure Frameworks Win](guides/why-post-failure.md)** — Why rules born from incidents beat rules born from best-practice lists
- **[Auto-Optimizing Skills](guides/auto-optimization.md)** — Eval-driven skill improvement: triage, iteration loop, 7 guardrails, data model

### Copy-Paste Rules
Individual rule files for `~/.claude/rules/` or `.claude/rules/`:

| Rule | What It Prevents |
|------|-----------------|
| [read-before-acting.md](examples/claude-code-rules/read-before-acting.md) | Guessing instead of reading — the #1 agent failure mode |
| [three-failure-stop.md](examples/claude-code-rules/three-failure-stop.md) | Brute-forcing failures instead of researching |
| [process-before-execution.md](examples/claude-code-rules/process-before-execution.md) | Skipping the process because "it's faster to just do it" |
| [scope-control.md](examples/claude-code-rules/scope-control.md) | Over-engineering, unrequested features, premature abstractions |
| [session-lifecycle.md](examples/claude-code-rules/session-lifecycle.md) | Cold starts and sessions that end without auditing delivery |
| [dependency-awareness.md](examples/claude-code-rules/dependency-awareness.md) | Breaking downstream code by not checking what depends on a change |

## Framework Structure (v1.1)

```
Section 0: Project Identity      — WHO you are and WHAT good looks like
  0.1 Role Declaration
  0.2 Output Contract
  0.3 Quality Criteria
  0.4 Boundaries
  0.5 Session Lifecycle
  0.6 Communication Standards

Section 1: Workflow Orchestration — HOW you work
  1.1 Plan Mode Default
  1.2 Subagent Strategy
  1.3 Autonomous Bug Fixing
  1.4 Tool Hierarchy

Section 2: Evidence-First Culture — WHAT you read before acting
  2.1 Read Before Acting
  2.2 Show Research
  2.3 First-Time Gate
  2.4 No-Guess Policy
  2.5 Dependency Awareness

Section 3: Circuit Breakers       — WHEN to stop
  3.1 Three-Failure Stop
  3.2 Process Before Execution
  3.3 Scope Control
  3.4 Collaboration Model

Section 4: Quality Gates          — HOW you verify
Section 5: Self-Improvement Loop  — HOW you learn
Section 6: Task Management        — HOW you track
Section 7: Core Principles        — WHY it all matters
```

## The Key Insight

Most agent failures come from the same root cause: **acting without reading.** The agent guesses a column name instead of checking the schema. It deploys with assumed config instead of reading the setup guide. It tries a fourth variation of a broken approach instead of stopping to research.

This framework's core principle: **one read is worth ten guesses.**

## Using This Framework?

If you've adopted any part of this framework, we'd like to hear about it. [Open an issue](https://github.com/m9751/agent-operating-framework/issues) and share:
- Which rules you adopted
- What failures they prevented (or what new rules you wrote)
- What's missing

The best rules come from real incidents. Your production failures make the framework better for everyone.

## Contributing

Have a rule born from a real production failure? Open a PR. Include:
- The rule itself
- "Why This Exists" with the date and cost of the failure
- What it prevents

Rules without incident reports are less likely to be merged — they're advice, not enforcement.

## License

MIT
