# Done Criteria Schema

> A `## Done Criteria` section in a plan is enforceable only if it is testable. This schema defines what testable means.

## Why this exists

The framework's incident #22 logged that proxy verification (file-existence checks, grep counts) is not the same as functional verification. Plans that close with prose like "we did the work" pass nothing — they are claims, not contracts.

A Done Criteria section under this schema is a **contract**: each line names an observable post-condition that a reviewer (or `scripts/validate-done-criteria.py`) can check. If the post-condition is not checkable in seconds without running the build again, it does not belong in Done Criteria.

## The format

Each Done Criterion is one numbered line. The line must contain at least one backtick-quoted **verb call** drawn from the whitelist below, followed by the target and the expected outcome. The line may also contain free-form prose explaining context.

```
1. `<verb> <target> <expected>` — optional prose explaining why
2. `<verb> <target> <expected>` — optional prose
```

The validator parses the plan markdown, locates the `## Done Criteria` section, and checks every numbered line for a backtick-quoted verb call.

## Verb whitelist

| Verb | Argument shape | Meaning | Example |
|---|---|---|---|
| `file_exists` | `<path>` | File at path exists | `` `file_exists scripts/foo.py` `` |
| `query_returns` | `<query description>` | Database query returns expected rows | `` `query_returns 6 rows from feature_flags` `` |
| `endpoint_returns` | `<status> <url-or-description>` | HTTP endpoint returns expected status | `` `endpoint_returns 200 https://example.com/api/health` `` |
| `count_gte` | `<N> <description>` | Count of named items is at least N | `` `count_gte 6 rule rows in coverage matrix` `` |
| `byte_length_gte` | `<N> <path>` | File at path has at least N bytes | `` `byte_length_gte 200 examples/claude-code-rules/foo.md` `` |
| `env_var_set` | `<NAME>` | Environment variable is set and non-empty | `` `env_var_set DATABASE_URL` `` |
| `hook_fires` | `<hook-script> <expected>` | Hook script's exit code matches expected | `` `hook_fires empty-rule-body-gate.sh rejects synthetic empty rule` `` |
| `ci_check_passes` | `<check_name>` | Named CI status check passes on the PR | `` `ci_check_passes rules-lint` `` |
| `tag_exists` | `<tag>` | Git tag exists on remote | `` `tag_exists v1.4` `` |

If your post-condition does not fit one of these verbs, the contract is probably too prose-shaped. Decompose it into smaller observable conditions until each fits.

## Good examples

```markdown
## Done Criteria

1. `tag_exists v1.4` — release shipped on remote
2. `file_exists scripts/validate-done-criteria.py` — validator script created
3. `ci_check_passes rules-lint.yml` on PR #N — CI accepts the changes
4. `count_gte 6` rule rows in AGENT_FRAMEWORK.md coverage matrix — all rules represented
5. `hook_fires empty-rule-body-gate.sh rejects synthetic empty rule` — hook actually blocks
6. `byte_length_gte 200 examples/claude-code-rules/new-rule.md` — rule body is not a stub
```

Each criterion is independently checkable, named, and has a deterministic outcome.

## Bad examples (these will fail validation)

```markdown
## Done Criteria

1. The validator works correctly  ← no verb, prose only
2. We added the matrix to AGENT_FRAMEWORK.md  ← no observable target/expected
3. Code is high quality  ← unmeasurable
4. Phase A complete  ← restates the phase, doesn't define done
5. Tests pass  ← no named test or check
```

These are the failure modes the schema exists to prevent. They look reasonable but cannot be reconciled by a reviewer in seconds — every one of them requires you to *run the build again* to know whether it's true.

## Validator behavior

`scripts/validate-done-criteria.py <plan_file>`:

1. Parses the markdown
2. Finds the first heading matching `## Done Criteria` (case-insensitive)
3. Reads numbered list items until the next `## ` heading or EOF
4. For each numbered item, checks for at least one backtick-quoted token whose first word matches an approved verb
5. Exits non-zero with per-line failures if any criterion lacks a verb call

CI integration: `rules-lint.yml` runs the validator on any plan file added or modified in a PR. PRs introducing or editing plans without schema-conformant Done Criteria fail the check.

## When the schema is wrong

If you have a real, observable post-condition that no current verb captures, open a PR adding the verb to the whitelist. The whitelist is meant to grow as the framework's adoption surface grows — but each addition must be a genuine new check shape, not a synonym.

## Relationship to §0.5 Phase 3

Section 0.5 of `AGENT_FRAMEWORK.md` mandates that Phase 3 (Close) diff promises vs delivery against a `## Done Criteria` section. Without this schema, "diff promises vs delivery" was prose vs prose — a check the framework's own incident log says is not verification. With this schema, the diff is a verb-by-verb reconciliation: every criterion is ✅ met / ❌ unmet (with evidence) / ⚠️ partial (with gap).
