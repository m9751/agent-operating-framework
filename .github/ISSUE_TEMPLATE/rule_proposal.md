---
name: Rule proposal
about: Propose a new rule or gate based on a real production incident
title: "[RULE] "
labels: rule-proposal
assignees: ''
---

**What happened?**
Describe the incident: what the agent did wrong, what the cost was.

**When did it happen?**
Month and year (day-precision not required).

**What does your proposed rule prevent?**
One sentence.

**Draft rule text**
Paste your proposed rule. It should include:
- The constraint ("never do X" or "always do Y first")
- The gate condition (when it applies)
- "Why this exists" with the incident

**Is there a hook that could enforce this?**
If yes, describe the enforcement logic (what tool call to intercept, what condition to check).

---

*Rules without incident reports are less likely to be merged — they're advice, not enforcement.*
