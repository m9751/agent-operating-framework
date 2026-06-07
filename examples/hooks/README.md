# Hook Examples

> **Platform:** These hooks use Claude Code's `PreToolUse`/`PostToolUse` lifecycle. They are written for bash on macOS/Linux/WSL. They will not work natively on Windows CMD/PowerShell — use WSL2 or adapt the shell syntax accordingly.

Production-quality hook scripts for enforcing agent discipline at the tool-call level. These hooks run as shell scripts before (or after) the agent invokes a tool, giving you a programmatic enforcement layer that supplements rule files.

## What Are Hooks?

Hooks are shell scripts that Claude Code executes at defined points in the tool-call lifecycle:

- **PreToolUse** — runs before a tool call executes. Can allow (exit 0), block (exit 2), or provide advisory output (exit 0 with stderr).
- **PostToolUse** — runs after a tool call completes. Useful for logging, breadcrumb tracking, and post-action verification.

The agent receives the hook's stdout/stderr as context, so blocked calls include the reason and guidance for the agent to self-correct.

## Configuring Hooks

Add hooks to `~/.claude/settings.json` (global) or `.claude/settings.json` (project-level):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "command": "/path/to/your/hook.sh"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read",
        "command": "/path/to/read-logger.sh"
      }
    ]
  }
}
```

**`matcher`** filters which tools trigger the hook:
- `"*"` — all tools
- `"Edit"` — only the Edit tool
- `"execute_sql"` — only a specific MCP tool

Each hook receives JSON on stdin describing the tool call:
```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/path/to/file.py",
    "old_string": "...",
    "new_string": "..."
  }
}
```

## The Breadcrumb Pattern

Several hooks in this directory use a **breadcrumb pattern** to enforce sequencing (e.g., "read before write" or "search before create"):

1. A **PostToolUse logger hook** watches for read/search operations and appends the resource name to a session-scoped temp file (the "breadcrumb").
2. A **PreToolUse gate hook** checks the breadcrumb file before allowing write/create operations.

Session scoping uses `$CLAUDE_SESSION_ID` (set automatically by Claude Code) to isolate breadcrumbs per conversation:

```bash
BREADCRUMB_FILE="${TMPDIR:-/tmp}/agent-reads-${CLAUDE_SESSION_ID:-unknown}.log"
```

### Example: Read-Logger (PostToolUse companion for read-gate.sh)

```bash
#!/usr/bin/env bash
# PostToolUse hook — logs reads to the breadcrumb file
set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
TOOL_INPUT="$(echo "$INPUT" | jq -r '.tool_input // empty')"

BREADCRUMB_FILE="${TMPDIR:-/tmp}/agent-reads-${CLAUDE_SESSION_ID:-unknown}.log"

case "$TOOL_NAME" in
  Read)
    FILE_PATH="$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')"
    [[ -n "$FILE_PATH" ]] && echo "$FILE_PATH" >> "$BREADCRUMB_FILE"
    ;;
  execute_sql)
    # Log SELECT queries as reads of the referenced tables
    QUERY="$(echo "$TOOL_INPUT" | jq -r '.query // empty')"
    if echo "$QUERY" | grep -qiE '^\s*SELECT'; then
      echo "$QUERY" >> "$BREADCRUMB_FILE"
    fi
    ;;
  Bash)
    CMD="$(echo "$TOOL_INPUT" | jq -r '.command // empty')"
    if echo "$CMD" | grep -qE '^(cat|head|tail|less|more) '; then
      echo "$CMD" >> "$BREADCRUMB_FILE"
    fi
    ;;
esac

exit 0
```

## Design Principles

### Block, Don't Nag

Hard gates (exit 2) are better than warnings the agent can ignore. If a behavior should never happen, block it. The agent receives the block reason and self-corrects.

### Fail-Open for Advisory Hooks

Advisory hooks (like `delivery-gate.sh`) always exit 0. They print reminders to stderr but never prevent work. Use advisory hooks for habits you want to build, not invariants you need to enforce.

### Session-Scoped Breadcrumbs

All breadcrumb files use `$CLAUDE_SESSION_ID` in the filename. This means:
- Each conversation has its own state
- No stale breadcrumbs from prior sessions
- Temp files are cleaned up by the OS automatically

### Keep Hooks Fast

Hooks run synchronously before every tool call. Keep them under 100ms. Avoid network calls, database queries, or heavy computation in hooks. If you need slow checks, run them asynchronously in a PostToolUse hook.

### Readable Block Messages

When a hook blocks (exit 2), its stdout becomes the agent's error context. Write block messages that:
1. Name what was blocked and why
2. Tell the agent exactly what to do instead
3. Include any relevant state (e.g., "Resources read so far: ...")

## Hook Inventory

| File | Type | Behavior | Purpose |
|------|------|----------|---------|
| `read-gate.sh` | PreToolUse | Hard block (exit 2) | Blocks writes to infrastructure unless a prior read was logged |
| `search-gate.sh` | PreToolUse | Hard block (exit 2) | Blocks code creation unless a prior search was logged |
| `delivery-gate.sh` | PreToolUse | Advisory (exit 0) | Reminds the agent to log deliverables to the tracking system |
| `deprecated-field-gate.sh` | PreToolUse | Hard block (exit 2) | Blocks tool calls that reference deprecated/obsolete field names |
| `secure-config-gate.sh` | PreToolUse | Hard block (exit 2) | Blocks tool calls containing secret patterns + Write to protected config paths |
| `focus-breadcrumb.sh` | UserPromptSubmit | Always exit 0 | Companion to focus-confirmation-gate. Detects explicit-task prompts (named target + actionable verb) and writes a session breadcrumb. |
| `focus-confirmation-gate.sh` | PreToolUse | Advisory (exit 0) | Warns when first Edit/Write/Bash fires with no focus breadcrumb in this session |
| `dormant-code-gate.sh` | CI lint | Hard block (exit 1) | Rejects PRs that modify code files whose every extracted symbol has zero callers elsewhere in the repo. Backs scope-discipline Gate 5. |
| `empty-rule-body-gate.sh` | CI meta-hook | Hard block (exit 1) | Pre-merge gate that rejects rule files (`examples/claude-code-rules/*.md`) with body bytes < 200 or missing a `## Why` section. Closes the empty-stub loophole flagged in INCIDENTS #25. |
| `breadcrumb-lib.sh` | Library | — (source only) | Shared session-scoped breadcrumb API: `bc_session_key`, `bc_dir`, `bc_write`, `bc_exists`, `bc_read`. Source into any hook that needs to log or check session state. |
| `startup-gate.sh` | SessionStart | Advisory (exit 0) | Checks repo, AGENTS.md, active plan, skills manifest, and hook registration at session start. Writes drift report to `~/.claude/startup-gate-report.md`. |
| `hook-telemetry-stop.sh` | Stop | Advisory (exit 0) | Reads fire/block breadcrumbs at session end; bulk-INSERTs one row per hook into a configurable telemetry store (set `AOF_TELEMETRY_URL` + `AOF_TELEMETRY_KEY`). |
| `lib/normalize-hook-input.sh` | Library | — (source only) | Normalizes hook payload field names (camelCase → snake_case) and tool-name literals (Grok → Claude Code). Source before any `tool_name` check for multi-runtime hooks. |

## The Focus-Confirmation Pair

`focus-breadcrumb.sh` + `focus-confirmation-gate.sh` work together to enforce session-lifecycle.md Phase 1 (focus confirmation before destructive action) without violating §1.3 precedence (explicit named-target requests don't need a second confirmation).

The pair uses two different hook events:

- **`focus-breadcrumb.sh`** runs on `UserPromptSubmit` — once per operator message. It scans the prompt for an explicit-task pattern (any of the verbs in `EXPLICIT_VERBS`, followed by at least one target token). If matched, it appends a `<timestamp>\t<verb>\t<context>` line to `${TMPDIR}/agent-focus-${CLAUDE_SESSION_ID}.log`.

- **`focus-confirmation-gate.sh`** runs on `PreToolUse` — once per tool call, but only acts on Edit/Write/Bash. If the breadcrumb file is missing or empty, it emits a `::warning::` to stderr and exits 0. Read/Grep/Glob are exempt because research is part of orientation, not destructive action.

Why two scripts, not one: the events fire at different points in the lifecycle. UserPromptSubmit fires once per turn; PreToolUse fires once per tool call. Same conversation, same session ID, shared breadcrumb.

Configuration: add both hooks to `settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "matcher": "*", "command": "/path/to/focus-breadcrumb.sh" }
    ],
    "PreToolUse": [
      { "matcher": "Edit|Write|Bash", "command": "/path/to/focus-confirmation-gate.sh" }
    ]
  }
}
```

## Watcher Hooks Under Branch-Protected Repos

Watcher-class hooks (FileSystemWatcher daemons, inotify cron, scheduled auto-push scripts) that run `git push origin main` will fail-loop indefinitely when branch protection requires a PR. The correct pattern:

1. Keep the `git commit` step — produces a local backup even when push is blocked.
2. Skip the `git push` step when branch protection is detected.
3. Log `PUSH-SKIPPED branch-protection-active` for auditability.
4. Use `# fail-mode: silent-skip` annotation — this is not a hook failure, it's a deliberate no-op.

Detection: catch exit code 1 from `git push` and grep stderr for `GH006` or `protected branch`. Log the skip and exit 0.

The operator's surfacing path is a manual PR from the auto-committed local branch.

See [AOF Incident #35](../../INCIDENTS.md) for the canonical case study.

## Getting Started

1. Copy the hooks you want to your hooks directory (e.g., `~/.claude/hooks/`)
2. Make them executable: `chmod +x ~/.claude/hooks/*.sh`
3. Add them to your `settings.json` (see configuration section above)
4. For breadcrumb-based hooks, add both the logger (PostToolUse) and the gate (PreToolUse)
5. Customize the configuration arrays at the top of each hook for your environment

## Customization Checklist

Each hook has a configuration section at the top. Before deploying, review:

- **`read-gate.sh`** — `WRITE_TOOLS` array (which tools count as writes)
- **`search-gate.sh`** — `CREATION_TOOLS` and `CREATION_PATTERNS` arrays
- **`delivery-gate.sh`** — `TRACKING_TABLES` and `NEW_WORK_SIGNALS` arrays
- **`deprecated-field-gate.sh`** — `DEPRECATED_FIELDS` array (your deprecated-to-current mappings)
- **`secure-config-gate.sh`** — `SECRET_REGEX` and `PROTECTED_PATH_REGEX`. Optionally extend the secret regex via the `AOF_SECRET_PATTERNS_FILE` env var (one extra regex per line).
- **`focus-breadcrumb.sh`** — `EXPLICIT_VERBS` (the verb list that constitutes "explicit task" intent)
- **`focus-confirmation-gate.sh`** — `GATED_TOOLS` array (which tools warrant the focus check)
- **`dormant-code-gate.sh`** — `MIN_SYMBOL_LEN` (minimum symbol length to count; default 6 to filter `init`/`main`/etc.) and `SKIP_EXTENSIONS_RE` (which extensions are not "code")
