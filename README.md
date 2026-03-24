# Agent Operating Framework

A battle-tested operating framework for AI coding agents — born from production failures, not theory.

## What This Is

A set of behavioral rules that make AI coding agents (Claude Code, Cursor, Copilot, etc.) more reliable. It combines:

- **Workflow orchestration** — plan mode, subagents, autonomous bug fixing
- **Evidence-first culture** — read before acting, show research, no guessing
- **Circuit breakers** — three-failure stop, process before execution
- **Quality gates** — verification before done, post-delivery checklist
- **Self-improvement** — capture lessons, escalate repeated failures to enforced rules

## Quick Start

### Option 1: Use as a CLAUDE.md
Copy `AGENT_FRAMEWORK.md` to your project root as `CLAUDE.md`. Claude Code will read it at session start.

### Option 2: Use as individual rules
Copy files from `examples/claude-code-rules/` to `~/.claude/rules/` for global enforcement, or to your project's `.claude/rules/` for project-scoped rules.

### Option 3: Cherry-pick
Read `AGENT_FRAMEWORK.md` and adopt the sections that match your pain points.

## Files

```
AGENT_FRAMEWORK.md              <- The full framework (use as CLAUDE.md)
examples/
  claude-code-rules/
    read-before-acting.md       <- 4-gate universal rule: read before you touch
    three-failure-stop.md       <- Stop after 3 failures, research instead
    process-before-execution.md <- Follow the process, even when it feels slow
```

## The Key Insight

Most agent failures come from the same root cause: **acting without reading.** The agent guesses a column name instead of checking the schema. It deploys with assumed config instead of reading the setup guide. It tries a fourth variation of a broken approach instead of stopping to research.

The framework's core principle: **one read is worth ten guesses.**

## Enforcement Architecture

Rules alone aren't enough. The framework includes an escalation model:

```
Memory (advice) → Rules (law) → Hooks (barriers)
```

- **Memory**: soft guidance the agent reads at session start
- **Rules**: hard constraints loaded before every action
- **Hooks**: automated gates that block tool execution

If the same mistake happens twice despite a memory entry, promote it to a rule. If a rule gets ignored, promote it to a hook.

## Origin

This framework was developed through real production work — MuleSoft deployments, Supabase queries, campaign systems, and infrastructure management. Every rule exists because its absence caused a specific, documented failure. The "Why This Exists" sections in each rule file link to the incidents that created them.

## License

MIT
