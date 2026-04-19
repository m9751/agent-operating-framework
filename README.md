# Agent Operating Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An operating framework for AI coding agents, refined through 12 months of enterprise sales workflow.

## Quick Start

Copy `AGENT_FRAMEWORK.md` to your project root as `CLAUDE.md`. Fill in Section 0 with your project specifics. Start a session.

```bash
cp AGENT_FRAMEWORK.md /path/to/your/project/CLAUDE.md
```

See [guides/getting-started.md](guides/getting-started.md) for the full adoption path.

## Who This Is For

You've set up CLAUDE.md. You've built a few skills. You're using Projects Memory. But outputs are still inconsistent, the agent ignores rules under pressure, and you're manually reviewing everything.

This framework is the next step. It adds enforcement (rules that can't be ignored), circuit breakers (stop after 3 failures), and an escalation model (advice → law → barriers) that makes your CLAUDE.md actually stick.

If you're just getting started with Claude Code, read the beginner guides first. If you've hit the wall where your CLAUDE.md "stops working," [start here](guides/from-beginner-to-framework.md).

## What This Is

A behavioral operating system for Claude Code that combines:

- **Project identity** — role, output contracts, quality criteria, session lifecycle
- **Evidence-first culture** — four gates: read before touching, first-time check, evidence card, no guessing
- **Circuit breakers** — three-failure stop, scope discipline, delivery protocol
- **Quality gates** — verification before done, post-delivery checklist, HTML token hygiene
- **Enforcement architecture** — memory (advice) → rules (law) → hooks (barriers)
- **Self-improvement** — capture lessons, escalate failures, consolidate when rules accumulate

**Claude Code note:** The hook implementations in `examples/hooks/` use Claude Code's `PreToolUse`/`PostToolUse` lifecycle. Rule prose is portable to any agent platform.

Every rule exists because its absence caused a specific, documented failure. See [INCIDENTS.md](INCIDENTS.md) for the log.

## Library Contents

### The Framework
- **[AGENT_FRAMEWORK.md](AGENT_FRAMEWORK.md)** — The complete framework (v1.3). Use as your project's CLAUDE.md.

### Guides
- **[From Beginner to Framework](guides/from-beginner-to-framework.md)** — You've built CLAUDE.md and skills but outputs are inconsistent. Here's why and what to do next.
- **[Getting Started](guides/getting-started.md)** — How to adopt the framework, where files go, recommended path
- **[Enforcement Architecture](guides/enforcement-architecture.md)** — Memory → Rules → Hooks escalation model with examples
- **[Rule Consolidation](guides/rule-consolidation.md)** — When rules accumulate past ~20, how to cluster by root cause and compress without losing lessons
- **[Why Post-Failure Frameworks Win](guides/why-post-failure.md)** — Why rules born from incidents beat rules born from best-practice lists
- **[Auto-Optimizing Skills](guides/auto-optimization.md)** — Eval-driven skill improvement: triage, iteration loop, 7 guardrails, data model

### Copy-Paste Rules
Individual rule files for `~/.claude/rules/` or `.claude/rules/`. Each absorbs multiple earlier rules into a single file with sub-gates:

| Rule | What It Prevents |
|------|-----------------|
| [read-before-acting.md](examples/claude-code-rules/read-before-acting.md) | Guessing instead of reading — 5 gates + three-failure stop |
| [scope-discipline.md](examples/claude-code-rules/scope-discipline.md) | Over-engineering, unapproved dependencies, building what already exists, remediating dormant code |
| [session-lifecycle.md](examples/claude-code-rules/session-lifecycle.md) | Cold starts, plan-mode violations, sessions that end without auditing delivery |
| [delivery-protocol.md](examples/claude-code-rules/delivery-protocol.md) | Scattered deliverables, skipped checklists, token-wasteful HTML iterations |
| [no-local-infrastructure.md](examples/claude-code-rules/no-local-infrastructure.md) | Persistent agents on the user's laptop instead of cloud-hosted solutions |
| [secure-configuration.md](examples/claude-code-rules/secure-configuration.md) | Config file overwrites, secrets in chat, wrong credentials on wrong system |

### Hook Examples
Shell scripts that enforce rules at the tool-call level — the third tier of the enforcement ladder. Copy to your hooks directory and configure in `settings.json`:

| Hook | Type | What It Enforces |
|------|------|-----------------|
| [read-gate.sh](examples/hooks/read-gate.sh) | Hard block | Blocks writes unless the target resource was read first |
| [search-gate.sh](examples/hooks/search-gate.sh) | Hard block | Blocks code creation unless a search was done first |
| [delivery-gate.sh](examples/hooks/delivery-gate.sh) | Advisory | Reminds agent to log deliverables (fail-open) |
| [deprecated-field-gate.sh](examples/hooks/deprecated-field-gate.sh) | Hard block | Blocks use of deprecated field names |

See [examples/hooks/README.md](examples/hooks/README.md) for setup instructions and the breadcrumb pattern.

### Incident Log
- **[INCIDENTS.md](INCIDENTS.md)** — 23 sanitized incidents linking real failures to the rules they produced. Month-precision dates.

## The Key Insight

Most agent failures come from the same root cause: **acting without reading.** The agent guesses a column name instead of checking the schema. It deploys with assumed config instead of reading the setup guide. It tries a fourth variation of a broken approach instead of stopping to research.

**Prompt instructions are not enforcement. They are guidance.** The only durable approach is an escalation ladder:

```
Memory (advice) → Rules (law) → Hooks (barriers)
```

Prose tells the model what it should do. Gates determine what it is allowed to do.

This framework's core principle: **one read is worth ten guesses.**

## Author

Built and maintained by [Michael Busacca](https://www.linkedin.com/in/enterprise-software-sales/) — 13+ years enterprise SaaS, running AI-assisted workflows in a high-volume sales context.

## Changes

See [CHANGELOG.md](CHANGELOG.md) for version history.
