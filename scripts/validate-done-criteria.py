#!/usr/bin/env python3
"""
validate-done-criteria.py

Parses a plan markdown file, locates the `## Done Criteria` section, and
validates each numbered criterion against the schema in
guides/advanced/done-criteria-schema.md.

Schema: every numbered criterion must contain at least one backtick-quoted
token whose first word matches an approved verb. Prose-only criteria fail.

Usage:
    python scripts/validate-done-criteria.py <plan_file> [<plan_file> ...]

Exit codes:
    0 — all criteria valid (or no Done Criteria section found, treated as N/A)
    1 — at least one criterion missing a verb call
    2 — usage error or file not readable
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

APPROVED_VERBS = frozenset(
    {
        "file_exists",
        "query_returns",
        "endpoint_returns",
        "count_gte",
        "byte_length_gte",
        "env_var_set",
        "hook_fires",
        "ci_check_passes",
        "tag_exists",
    }
)

DC_HEADING_RE = re.compile(r"^##\s+done\s+criteria\b", re.IGNORECASE)
NEXT_H2_RE = re.compile(r"^##\s+\S")
NUMBERED_LINE_RE = re.compile(r"^\s*(\d+)\.\s+(.*)$")
BACKTICK_TOKEN_RE = re.compile(r"`([^`\n]+)`")


def extract_done_criteria(text: str) -> list[tuple[int, str]]:
    """Return a list of (line_number, content) for each numbered DC item.

    Returns empty list if no Done Criteria section is found.
    """
    lines = text.splitlines()
    in_dc = False
    items: list[tuple[int, str]] = []

    for idx, line in enumerate(lines, start=1):
        if DC_HEADING_RE.match(line):
            in_dc = True
            continue
        if in_dc and NEXT_H2_RE.match(line):
            break
        if not in_dc:
            continue

        m = NUMBERED_LINE_RE.match(line)
        if m:
            items.append((idx, m.group(2)))

    return items


def has_approved_verb(content: str) -> bool:
    """Return True if any backtick-quoted token's first word is approved."""
    for tok in BACKTICK_TOKEN_RE.findall(content):
        first_word = tok.strip().split(None, 1)[0] if tok.strip() else ""
        if first_word in APPROVED_VERBS:
            return True
    return False


def validate_plan(path: Path) -> tuple[int, int, list[str]]:
    """Validate one plan file.

    Returns (criteria_count, failure_count, error_messages).
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return 0, 0, [f"{path}: cannot read ({exc})"]

    items = extract_done_criteria(text)
    if not items:
        return 0, 0, []

    failures: list[str] = []
    for line_no, content in items:
        if not has_approved_verb(content):
            preview = content[:80] + ("..." if len(content) > 80 else "")
            failures.append(
                f"{path}:{line_no}: criterion has no approved verb call — {preview!r}"
            )

    return len(items), len(failures), failures


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(
            "usage: python scripts/validate-done-criteria.py <plan_file> [<plan_file> ...]",
            file=sys.stderr,
        )
        return 2

    total_criteria = 0
    total_failures = 0
    all_errors: list[str] = []
    files_with_dc = 0

    for arg in argv[1:]:
        path = Path(arg)
        criteria, failures, errors = validate_plan(path)
        if criteria > 0:
            files_with_dc += 1
        total_criteria += criteria
        total_failures += failures
        all_errors.extend(errors)

    if all_errors:
        for err in all_errors:
            print(err, file=sys.stderr)
        print(
            f"\nDone Criteria validation: {total_failures} failure(s) "
            f"across {total_criteria} criteria in {files_with_dc} plan(s)",
            file=sys.stderr,
        )
        return 1

    print(
        f"Done Criteria validation: {total_criteria} criteria in "
        f"{files_with_dc} plan(s) — all schema-conformant"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
