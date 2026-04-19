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
