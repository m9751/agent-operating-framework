# Dependency Awareness — MANDATORY

## The Rule
Before changing something, check what depends on it.

## What "Check Dependencies" Means
- Deleting a function? Grep for imports and call sites
- Changing a schema (table, column, view)? Check what queries or views reference it
- Modifying a config file? Check what reads it at build or runtime
- Renaming a file? Check what imports or references it by path
- Changing an API response shape? Check what clients consume it

## The Pattern
1. Read the thing you're about to change
2. Search for what references or depends on it
3. Include dependent changes in the same commit — or flag them explicitly

## The Test
If a change breaks something downstream that a grep would have caught, this rule was skipped.
