# Persistence Hosting — Decision Framework

> Filename retained as `no-local-infrastructure.md` for link stability.
> The original v1.3 rule was a categorical ban on local persistence; v1.4 reframes it as a context-dependent decision keyed to four axes. The operator-availability insight from the original incident is preserved as one axis among four, not the universal answer.

## The Question

Before building any persistent infrastructure (agents, schedulers, queues, databases, state stores), answer the question that produces a hosting recommendation:

**If the host machine is off for a week, what happens?**

The answer is not always "cloud-hosted required." It depends on four axes.

## The Four Axes

| Axis | Question to answer | Outcome shifts toward |
|---|---|---|
| **Durability requirement** | What is the cost of losing this data or this run? | High cost → managed durable storage |
| **Recovery posture** | When the host goes down, what is the expected RPO/RTO? | Tight RPO/RTO → cloud-hosted |
| **Trust boundary** | Does this data leave the operator's regulatory or contractual perimeter? | Strict perimeter → on-prem / VPC |
| **Operator availability** | Will the host machine be on, awake, and maintained for the workload's lifetime? | Low availability → cloud-hosted |

These compose. A regulated workload with strict trust boundary AND high operator availability runs on-prem fine. A hobby workload with low operator availability and lax trust boundary belongs in cloud. Most decisions fall between.

## Decision Table

| Scenario | Durability | Recovery | Trust boundary | Operator availability | Recommendation |
|---|---|---|---|---|---|
| Regulated / HIPAA / SOC 2 workload | high | tight | strict | varies | **on-prem allowed**; cloud only with BAA + matching attestations |
| Air-gapped network | varies | local-only | strictest | typically high | **local required**; cloud forbidden |
| Consumer-facing SaaS automation | moderate | 24/7 expected | low | low (laptop sleeps, travels) | **cloud preferred** — operator-availability gap dominates |
| On-prem dev / ops automation | low | scheduled | low (internal) | high (ops team owns uptime) | **either acceptable**; pick by cost / skill |
| Personal dev tooling, build helpers | low | best-effort | low | depends | **either acceptable**; cloud reduces ops burden but is not required |

When in doubt: solve the operator-availability question first (it produces the most decisive shift), then layer durability + trust boundary on top.

## What This Replaces

A categorical "never build local persistent infrastructure" rule, framed as non-negotiable. That framing taught the wrong invariant for stacks where local persistence is the right answer (regulated, air-gapped, on-prem ops). The new framing keeps the original insight — operator availability matters — without forcing it onto contexts where it is not the dominant axis.

## Why

A specific class of failure motivates this rule: persistent local infrastructure built without checking whether a cloud-hosted alternative existed, on a machine the operator could not commit to keeping running. The fix is not "always cloud." The fix is **answer the four questions before building**, and let the answers route the decision.

The original incident: 5 persistent worker agents put on an operator's laptop with zero backup, zero redundancy, no search for alternatives. A 247k-star cloud-hosted platform did everything the workers did. The operator-availability axis was decisive in that context (consumer SaaS workflow, low ops commitment), and the agent never asked. See [INCIDENTS.md](../../INCIDENTS.md) row 15.

The general lesson: ceremony must match blast radius. Build local when the four axes route you there. Build cloud when they route you there. Don't build either by default.
