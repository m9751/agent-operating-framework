# Getting Started

> How to adopt the Agent Operating Framework in your own Claude Code projects.

## Quick Start (5 minutes)

1. Copy `AGENT_FRAMEWORK.md` to your project root as `CLAUDE.md`
2. Fill in Section 0 (Project Identity) with your project specifics
3. Start a Claude Code session — it reads `CLAUDE.md` automatically

That's it. The framework is now active.

## Recommended Adoption Path

Don't adopt everything at once. Start with what hurts most:

### If your agent keeps guessing instead of reading:
Copy `examples/claude-code-rules/read-before-acting.md` to `~/.claude/rules/`

### If your agent brute-forces failures:
Copy `examples/claude-code-rules/three-failure-stop.md` to `~/.claude/rules/`

### If your agent over-engineers or adds unrequested features:
Copy `examples/claude-code-rules/scope-control.md` to `~/.claude/rules/`

### If sessions start cold with no context:
Copy `examples/claude-code-rules/session-lifecycle.md` to `~/.claude/rules/`

### If changes break downstream dependencies:
Copy `examples/claude-code-rules/dependency-awareness.md` to `~/.claude/rules/`

## Where Rules Live

```
~/.claude/rules/          ← Global rules (apply to all projects)
.claude/rules/            ← Project rules (apply to this project only)
CLAUDE.md                 ← Project root (loaded every session)
```

**Global rules** go in `~/.claude/rules/`. Use for universal behavior like "read before acting" that applies everywhere.

**Project rules** go in `.claude/rules/` inside your repo. Use for project-specific constraints like "always use pytest, not unittest."

**CLAUDE.md** goes in the project root. Use for project identity, output contracts, and high-level guidance.

## File Structure

A mature project using this framework:

```
my-project/
├── CLAUDE.md                    ← Section 0 filled in, points to rules/
├── .claude/
│   └── rules/
│       └── project-specific.md  ← Project-scoped rules
├── src/
└── ...
```

Your home directory:

```
~/.claude/
├── rules/
│   ├── read-before-acting.md    ← Universal
│   ├── three-failure-stop.md    ← Universal
│   ├── scope-control.md         ← Universal
│   └── session-lifecycle.md     ← Universal
└── projects/
    └── <project>/
        └── memory/
            └── MEMORY.md        ← Persistent memory for this project
```

## Growing the System

1. **Start with CLAUDE.md only.** Fill in Section 0. Use the framework as-is.
2. **When a mistake happens, write a memory entry.** Soft guidance.
3. **When the same mistake happens again, promote to a rule.** Hard constraint.
4. **When a rule gets ignored, promote to a hook.** Automated enforcement.

Read `guides/enforcement-architecture.md` for the full escalation model.

## What NOT to Do

- Don't adopt all 7 sections on day one — start with what hurts
- Don't write rules for problems you haven't had — rules without incident reports get ignored
- Don't put everything in CLAUDE.md — it loads every session, keep it lean
- Don't skip Section 0 — without identity and output contracts, the rest is enforcement without direction
