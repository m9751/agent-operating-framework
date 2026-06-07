# AGENTS.md Governance Standard

> How a repo declares its agent governance contract.

When an AI agent opens a repository it has never worked in before, it operates without context. It does not know what the repo is for, which files are safe to modify, what the deployment process looks like, or whether there are agent-specific rules to follow. Without a governance declaration, every session starts cold.

`AGENTS.md` is the solution: a file at the repository root that declares the governance contract for agents working in the repo. It is the first file an agent reads (AOF rule: `read-before-acting.md` Gate 0c) and the canonical source for repo-level agent behavior.

---

## Three Levels

### Level 1 — Identity Only

The minimum viable `AGENTS.md`. One sentence identifying the repo, one sentence on what agents should do there. Establishes presence without investing significant documentation effort.

```markdown
# AGENTS.md

This is the **my-project** repo. Agents: default to reading before writing; use the PR workflow for all changes.
```

**When to use:** New repo, early project, or repo where AI agent work is infrequent.

---

### Level 2 — Identity + Routing Table

Adds a routing table that maps task types to the correct files, patterns, or subagents. Prevents agents from guessing where things live.

```markdown
# AGENTS.md

This is the **my-project** API service.

## Routing

| Task | Where to look |
|---|---|
| API changes | `src/api/` — read `src/api/README.md` first |
| Database migrations | `supabase/migrations/` — use `apply_migration` MCP, never raw SQL |
| Deployment | `scripts/deploy.sh` — read it before running |
| Tests | `npm test` — must pass before any PR |
```

**When to use:** Active repo where multiple types of work happen and agents need direction without reading every file.

---

### Level 3 — Identity + Routing + Procedures + ADR Register

The full governance contract. Adds numbered procedures (step-by-step, checkable) and an ADR register (key architectural decisions that agents must not reverse without reading the record).

```markdown
# AGENTS.md

This is the **my-project** API service. Agents: read this file first, every session.

## Routing

| Task | Where to look |
|---|---|
| API changes | `src/api/` |
| Schema changes | `supabase/migrations/` |

## Procedures

### Adding a new endpoint

1. Read `src/api/README.md` — routing conventions and auth patterns
2. Read the existing handler closest to what you're building
3. Add route to `src/api/routes.ts`, handler to `src/api/handlers/`
4. Add tests to `tests/api/`
5. Run `npm test` — must pass before opening PR
6. PR title: `feat(api): <endpoint-name>`

### Schema changes

1. Never use `execute_sql` for DDL — use `apply_migration` MCP only
2. Name the migration: `<timestamp>_<description>.sql`
3. Commit the migration file to `supabase/migrations/` in the same PR
4. After merge, run `npm run types` to regenerate TypeScript types

## ADR Register

Key decisions. Read the ADR before reversing any of these:

| ADR | Decision | Do not reverse without reading |
|---|---|---|
| ADR-001 | All auth handled by middleware, not per-route | `docs/adr/001-auth-middleware.md` |
| ADR-002 | Supabase for all persistence (no local DB) | `docs/adr/002-supabase-only.md` |
```

**When to use:** Production repo, multi-agent environment, or any repo where a wrong agent decision would be expensive to reverse.

---

## What Makes a Good AGENTS.md

**Procedures must be numbered and checkable.** A procedure that says "deploy carefully" is not a procedure. A procedure that says "1. Run `npm test`. 2. Run `./scripts/deploy.sh staging`. 3. Verify endpoint returns 200." is checkable — an agent can tick each step.

**The routing table must be accurate.** An AGENTS.md that points to files that don't exist, or omits the most common task type, is worse than no AGENTS.md — it misdirects. Keep it current.

**ADRs prevent expensive reversals.** If your team spent a week debating whether to use Supabase vs. a custom database and chose Supabase, that decision belongs in an ADR and a pointer in AGENTS.md. The next agent to open the repo will not know the debate happened.

**Identity sentence = one sentence.** Agents read the first few lines to orient. "This is the X repo" with a single defining sentence is enough. Don't write a paragraph — it competes with the content that follows.

---

## The Startup Gate Check

The AOF's `startup-gate.sh` hook (v1.7) checks for AGENTS.md presence at session start:

- **AGENTS.md found:** reports the identity sentence and whether a Procedure section exists
- **AGENTS.md not found:** flags as a drift item in the startup report

This means a repo without AGENTS.md will produce a "cold start without repo governance" notice at the start of every agent session — a gentle but persistent incentive to add it.

---

## Reference Implementations

Two Level 3 implementations shipped in the private `smokin-os` and `smokin-memory` repos on 2026-06-07. Key patterns from those files:

- **`smokin-os/AGENTS.md`** — declares the repo as infrastructure (Claude Code OS) with a 3-level agent contract: identity, routing by module (hooks, rules, skills, references), and a list of protected files that must not be modified without a PR.
- **`smokin-memory/AGENTS.md`** — declares the repo as a memory management layer with procedures for the three operations: retain, recall, and (when available) forget.

Both files include a `## What agents must not do` section — a short list of invariants that are easy to violate accidentally. This section is the most important part of any governance declaration: it names the landmines.

---

## Related

- [`read-before-acting.md` Gate 0c](../../examples/claude-code-rules/read-before-acting.md) — Gate 0c mandates reading AGENTS.md as the first action in any new repo
- [`examples/hooks/startup-gate.sh`](../../examples/hooks/startup-gate.sh) — Check 1 (repo detection) and Check 2 (AGENTS.md verification) at session start
- [`AGENT_FRAMEWORK.md` §0.1](../../AGENT_FRAMEWORK.md) — Role Declaration (the AGENTS.md equivalent for the project-level CLAUDE.md)
