# Secure Configuration — MANDATORY

## The Rule
Protect shared config files, never expose secrets in chat, and label every external configuration with its target.

## Requirements

### Config File Protection
- **NEVER** overwrite shared config files — use targeted edits, with a backup first
- Always `cp file file.bak` before editing any config file
- Read handoff notes or documentation about a config file before modifying it

### Secrets Handling
- **NEVER** accept API keys, tokens, or passwords in chat
- Use the platform's secret management (environment variables, keychain, vault)
- If you catch yourself asking "paste it here" — stop. Use the secure channel.

### Configuration Hygiene
- Bake non-secret configuration into the project's config files
- External secret stores are for secrets ONLY
- Label every external config file with what system it belongs to
- Before deploying, verify the config matches the target system

## NEVER:
- Rely on the user manually entering values into a production dashboard
- Deploy without verifying which system the config belongs to
- Modify shared config files without reading their documentation first

## Why
- Shared config file overwritten 4 times in one session, session terminated.
- API key exposed in chat.
- Wrong credentials deployed to the wrong system.
