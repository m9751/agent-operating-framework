# Go Hook Dispatch Pattern

> Ship a Go binary for performance. Ship a bash floor for portability. Always ship both.

Some AOF hooks implement their gate logic in Go — compiled to a native binary for sub-millisecond execution. The Go binary is architecture-specific: a Mach-O arm64 binary cannot run on Windows or x86 Linux. Shipping a binary without a fallback means the gate fails open (or errors) on every machine where the binary cannot execute. That is a security regression.

The dispatch pattern solves this with a three-layer stack:

```
claim-evidence-gate-dispatch.sh   ← settings.json points here (always runs)
    ↓ probes binary               ← uses it if runnable on THIS OS
claim-evidence-gate (binary)      ← fast path: Go, architecture-specific
    ↓ fallback
claim-evidence-gate.sh            ← bash floor: same gate logic, cross-platform
```

---

## Why Not Point settings.json Directly at the Binary?

The 2026-06-13 incident: a Mach-O arm64 binary was deployed. `settings.json` pointed directly at it. On Win11, the binary could not execute. The harness treated the non-zero exit as a non-block (the fail-open default for execution errors). Gate 4 was silently disabled on Windows for the entire deployment period.

The dispatch wrapper exists to prevent this exact failure mode.

---

## The Two-Probe Trust Model

A naive dispatcher checks `[ -x "$binary" ]` and runs it if executable. This trusts a tampered binary that returns 0 on everything. Because the binary suppresses the bash fallback when trusted, a compromised allow-all binary would wave every claim through.

The AOF dispatch wrapper uses two probes before trusting the binary:

```bash
PROBE_CLEAN='{"tool_input":{"file_path":"/nonexistent/__probe__.txt","content":"probe ok"}}'
PROBE_CLAIM='...'  # synthetic payload that looks like a claim

# Binary is trusted only if it BOTH:
#   - allows a clean payload (exit 0)
#   - blocks a claim-shaped payload (exit 2)
```

A binary that fails either probe falls through to the bash floor.

---

## Building a Go Hook

### Structure

```
hooks/
  myhook-gate/          ← Go module root
    main.go
    go.mod
  myhook-gate.sh        ← bash floor (identical gate logic)
  myhook-gate-dispatch.sh  ← dispatch wrapper (points to both)
```

### Build at install time

The binary must be built from source on the target machine, not cross-compiled and committed. This ensures the architecture matches.

```bash
# In your install script (make install / install.bat equivalent):
cd hooks/myhook-gate
go build -o ../myhook-gate .
chmod +x ../myhook-gate
```

The binary is gitignored (architecture-specific). The source is committed. Any machine with Go installed can build it. Machines without Go fall through to the bash floor automatically.

```gitignore
# hooks/.gitignore
myhook-gate
myhook-gate.exe
```

### Probe shapes

Your dispatch wrapper must construct probes that match your gate's allow/block logic. The probes must be synthetic (not real paths or real claims) and must not log false-positive telemetry.

Use a sentinel path prefix (`__probe__`, `__ceg_probe__`) that your gate's allowlist or path-existence check can distinguish from real traffic if needed.

---

## Bash Floor Requirements

The bash floor must implement the same gate logic as the Go binary. Divergence between the two is the failure mode the AOF Grok cross-layer batch (2026-06-15) was built to eliminate.

Checklist before shipping:
- [ ] Same assertion patterns (copy the pattern list verbatim from Go source)
- [ ] Same allowlist paths
- [ ] Same fail-closed / fail-open posture on empty stdin
- [ ] Same empty-stdin guard (whitespace-only = unevaluable = block)
- [ ] Same dual-shape conflict handling if applicable

If the Go binary is softened (e.g., ADR 0064 removed bare "confirmed" from patterns), the bash floor must receive the same softening. An unsoftened bash floor that over-blocks relative to the binary is a divergence — it erodes trust in the gate by generating false positives on the fallback path.

---

## Settings.json Registration

Register the dispatch wrapper three ways if your hook covers multiple events:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/myhook-gate-dispatch.sh" }]
      }
    ]
  }
}
```

Never register the binary directly. Never register the bash floor directly. Always register the dispatch wrapper.

---

## Fleet Verification

Alignment between the bash floor and Go binary requires two ongoing checks:

**1. Parity smoke** — run after every `make install` / `install.bat` to prove the bash floor and Go binary agree on all known cases. The private `claude-config` fork ships this at `tests/smoke/hooks/claim-evidence/parity-smoke.sh`. If you maintain your own fork, build a comparable test from your gate's `patterns_test.go` cases (the Go test file is the canonical source of truth for expected allow/block behavior).

**2. Fallback rate telemetry** — the dispatch wrapper should log `gate-path-go` or `gate-path-bash` on every invocation (via `bc_append` or equivalent). Query this log periodically:

```bash
grep 'gate-path-' ~/.claude/migration-breadcrumbs/.errors.log | tail -20
```

If `gate-path-bash` exceeds ~1% over a 7-day window, the Go binary is not loading reliably on one or more machines — investigate before porting bash exclusions. Telemetry is the decision gate, not intuition.

**Kill trigger:** if bash fallback rate stays elevated after fixing the binary, port the Go binary's `narrativeExclusions` (fence, blockquote, narrative-context skips) to the bash floor. Until then, the 4 known divergences are accepted (blockquote content, past-event descriptions, "described as", narrative learning-log lines).
