# Contributing

## The Bar

Every rule in this framework was born from a real failure. That standard applies to contributions too.

**Rules require a named incident.** Before a rule is merged, it must include:
- What happened (what the agent did wrong)
- When it happened (month-year precision is fine)
- What it cost (time, broken systems, wasted work)
- What the rule prevents

Rules without incident reports are advice, not enforcement. Advice is easier to ignore.

## What This Means in Practice

Good PR: "Added Gate 5 — dormant code check. In 2026-04, an agent proposed 8 phases of governance work on a file with zero callers. This gate requires a caller-grep before any remediation plan is proposed."

Not a good PR: "Added a rule about always writing tests, seems like good practice."

## Scope

This framework is Claude Code-specific in its hook implementations. Rule prose is portable to other agent platforms, but hooks use Claude Code's `PreToolUse`/`PostToolUse` lifecycle. If you're adapting hooks for another platform, note it in the PR.

## Process

1. Fork the repo
2. Add your rule to `examples/claude-code-rules/` or your hook to `examples/hooks/`
3. Reference it from `AGENT_FRAMEWORK.md` if it's a new behavioral section
4. Add an entry to `INCIDENTS.md` for the incident that produced the rule
5. Open a PR with a description that includes the incident summary

No CI, no automated tests. Review is manual and best-effort.
