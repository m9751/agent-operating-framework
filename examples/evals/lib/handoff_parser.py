"""Parse Michael's handoff notes — YAML frontmatter + structured markdown sections.

Handles 3 Done Criteria body formats found in the Phase 0 baseline corpus:
  1. Numbered list:     `1. text ✅` / `1. text ❌`
  2. Markdown table:    `| 1 | text | ✅ MET | ... |`
  3. Inline emoji list: `✅ item · ✅ item · ❌ item`

Header match is prefix-anchored — `## Done Criteria — Promise vs Delivery` and
`## Done Criteria — all 14 PASSED` both qualify, not just exact `## Done Criteria`.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class DoneCriterion:
    text: str
    met: bool


@dataclass
class Handoff:
    session_date: str
    machine: str
    tokens_input: Optional[int] = None
    tokens_output: Optional[int] = None
    cost_usd: Optional[float] = None
    done_criteria: list[DoneCriterion] = field(default_factory=list)
    errors: str = ""
    body: str = ""

    def dc_met_count(self) -> int:
        return sum(1 for dc in self.done_criteria if dc.met)

    def dc_total_count(self) -> int:
        return len(self.done_criteria)


_FRONTMATTER = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)
_DC_HEADER = re.compile(r"^##\s+Done Criteria\b.*$", re.MULTILINE)
_ERRORS_HEADER = re.compile(r"^##\s+Errors\b.*$", re.MULTILINE)
_NEXT_H2 = re.compile(r"^##\s+", re.MULTILINE)

# Format 1 — numbered list with trailing emoji
_NUMBERED_LINE = re.compile(r"^\s*\d+\.\s+(.*?)(✅|❌)\s*(.*)$")
# Format 2 — markdown table row: `| n | text | ✅ ... |` (skip header + separator rows)
_TABLE_ROW = re.compile(r"^\s*\|\s*\d+\s*\|\s*(.+?)\s*\|\s*(✅|❌)([^|]*)\|")
# Format 3 — inline emoji list separator-tolerant
_INLINE_EMOJI = re.compile(r"(✅|❌)\s*([^·✅❌\n]+)")


def _parse_frontmatter(raw: str) -> tuple[dict, str]:
    m = _FRONTMATTER.match(raw)
    if not m:
        return {}, raw
    fm_raw, body = m.group(1), m.group(2)
    fm = {}
    for line in fm_raw.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    return fm, body


def _extract_section(body: str, header_re: re.Pattern) -> str:
    """Return the body of a `## Heading...` section up to the next `## ` heading or EOF."""
    m = header_re.search(body)
    if not m:
        return ""
    start = m.end()
    next_h2 = _NEXT_H2.search(body, pos=start)
    end = next_h2.start() if next_h2 else len(body)
    return body[start:end].strip()


def _parse_done_criteria(section: str) -> list[DoneCriterion]:
    """Try each of the 3 known DC body formats in priority order.

    Returns the first non-empty result. Empty list if no format matches —
    that's the sparse-signal case from Phase 0 (41 of 47 handoffs).
    """
    if not section:
        return []

    # Format 1 — numbered list
    numbered: list[DoneCriterion] = []
    for line in section.splitlines():
        m = _NUMBERED_LINE.match(line)
        if m:
            numbered.append(DoneCriterion(text=m.group(1).strip(), met=m.group(2) == "✅"))
    if numbered:
        return numbered

    # Format 2 — markdown table
    table: list[DoneCriterion] = []
    for line in section.splitlines():
        m = _TABLE_ROW.match(line)
        if m:
            table.append(DoneCriterion(text=m.group(1).strip(), met=m.group(2) == "✅"))
    if table:
        return table

    # Format 3 — inline emoji list (single line or paragraph of ✅/❌ items)
    inline: list[DoneCriterion] = []
    for m in _INLINE_EMOJI.finditer(section):
        text = m.group(2).strip(" ·\t")
        if text:
            inline.append(DoneCriterion(text=text, met=m.group(1) == "✅"))
    return inline


def parse_handoff(path: Path) -> Handoff:
    raw = Path(path).read_text(encoding="utf-8")
    fm, body = _parse_frontmatter(raw)
    dc_section = _extract_section(body, _DC_HEADER)
    errors_section = _extract_section(body, _ERRORS_HEADER)
    # "None." or empty body → treat as no errors
    if errors_section.strip().lower() in ("", "none.", "none"):
        errors_section = ""

    return Handoff(
        session_date=fm.get("session_date", ""),
        machine=fm.get("machine", "unknown"),
        tokens_input=int(fm["tokens_input"]) if fm.get("tokens_input") else None,
        tokens_output=int(fm["tokens_output"]) if fm.get("tokens_output") else None,
        cost_usd=float(fm["cost_usd"]) if fm.get("cost_usd") else None,
        done_criteria=_parse_done_criteria(dc_section),
        errors=errors_section,
        body=body,
    )
