# Enforcement Architecture: Memory → Rules → Hooks

> Rules without teeth get ignored. This guide explains how to make agent behavior stick.

## The Problem

You write a rule: "Always read the file before editing it." The agent follows it for a while, then stops. You remind it. It follows it again. Then stops again.

The issue isn't the rule. The issue is that the rule has no enforcement mechanism. It's advice, and advice gets ignored under pressure.

## The Three Levels

```
Memory (advice) → Rules (law) → Hooks (barriers)
```

### Level 1: Memory
**What it is:** Soft guidance stored in files the agent reads at session start.

**How it works in Claude Code:** Write a memory file in `~/.claude/projects/<project>/memory/`. The agent reads `MEMORY.md` at the start of every conversation.

**When to use:** First time you notice a pattern. "The agent keeps guessing column names instead of checking the schema." Write a memory entry.

**Strength:** Low friction to create. Easy to update.
**Weakness:** The agent can ignore it. Nothing enforces compliance.

### Level 2: Rules
**What it is:** Hard constraints the agent reads before acting.

**How it works in Claude Code:** Write a `.md` file in `~/.claude/rules/` (global) or `.claude/rules/` (project-scoped). Rules are loaded into every conversation with higher priority than memory.

**When to use:** When a memory entry gets ignored twice. "I wrote a memory about reading schemas first, but the agent guessed column names again in the last two sessions." Promote it to a rule.

**Strength:** Higher priority in the agent's context. Explicit "MANDATORY" framing.
**Weakness:** The agent can still technically ignore it. Nothing blocks the tool call.

### Level 3: Hooks
**What it is:** Automated gates that fire before or after tool execution. They can block, modify, or log tool calls.

**How it works in Claude Code:** Configure hooks in `~/.claude/settings.json` under `hooks`. A `PreToolUse` hook runs before the agent executes a tool. If the hook returns an error, the tool call is blocked.

**When to use:** When a rule gets ignored despite being explicitly written. "I have a rule that says 'never run destructive git commands without asking,' but the agent ran `git reset --hard` anyway." Add a hook that blocks `git reset --hard`.

**Strength:** The system enforces it. The agent cannot bypass it.
**Weakness:** Higher friction to create. Requires shell scripting. Can over-constrain if poorly designed.

## The Escalation Principle

```
Mistake happens once → write a memory entry (advice)
Same mistake happens twice → promote to a rule (law)
Rule gets ignored → promote to a hook (barrier)
```

Each level costs more to create but is harder to ignore. The goal is to start light and escalate only when needed.

## Example: Schema Guessing

**Day 1 — Memory:**
> "When querying the database, check the schema reference first. Column names vary between tables."

**Day 5 — Rule (memory was ignored twice):**
```markdown
# Read Schema Before Querying — MANDATORY
Before writing ANY database query, read the schema reference first.
Never guess column names. Check `information_schema.columns` if the reference is stale.
```

**Day 10 — Hook (rule was ignored):**
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "echo 'REMINDER: Did you read the schema before writing this query?' >&2"
      }]
    }]
  }
}
```

## Design Principles

1. **Start light.** Don't jump to hooks. Most issues are fixed by a well-written rule.
2. **Document the incident.** Every rule should have a "Why This Exists" section with the date and cost of the failure that created it.
3. **Keep rules specific.** "Be careful" is not a rule. "Read the config file before deploying" is a rule.
4. **Hooks should block, not nag.** A hook that prints a warning gets ignored like a memory entry. A hook that blocks the tool call and returns an error forces the agent to comply.
5. **Review and prune.** Rules accumulate. Consolidate overlapping rules. Remove rules for patterns you've fully internalized.
