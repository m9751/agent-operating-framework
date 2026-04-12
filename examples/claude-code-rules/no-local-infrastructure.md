# No Local Infrastructure — MANDATORY

## The Rule
Never build persistent infrastructure that depends on the user's machine being on, awake, or maintained. All persistent systems must be cloud-hosted with inherent durability.

## Before Building ANY Agent, Orchestration, or Automation:
1. **Search for existing cloud-hosted solutions** — GitHub Actions, scheduled triggers, hosted agent platforms
2. **Show the user what exists** with trade-offs
3. **Only build if nothing fits**
4. **If building: must be cloud-hosted** — the test is "if the user's machine is off for a week, does everything still run?"

## NEVER:
- Run agents locally that need to persist
- Store state in local-only databases
- Choose local over cloud because it's faster for the agent to build
- Skip the search because "I already know how to build it"
- Say "we'll migrate to cloud later" — there is no later

## Acceptable Local Use:
- Build/test scripts before deploying to cloud
- One-time data transforms
- Development and debugging

## Why
An agent put 5 persistent workers on the user's laptop with zero backup, zero redundancy. A cloud-hosted platform did everything those workers did — but the agent never searched for it, never proposed it. It built local because building was faster for the agent, not better for the user.
