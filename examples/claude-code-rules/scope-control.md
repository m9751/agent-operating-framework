# Scope Control — MANDATORY

## The Rule
Do not exceed what was asked. The right amount of complexity is the minimum needed for the current task.

## What This Means
- Don't add features beyond the request
- Don't refactor adjacent code that wasn't part of the task
- Don't add error handling for scenarios that can't happen
- Don't add comments, docstrings, or type annotations to code you didn't change
- Three similar lines of code is better than a premature abstraction
- A bug fix doesn't need surrounding code cleaned up
- Don't design for hypothetical future requirements

## The Test
If the user asks "why did you change that?" and the answer is "while I was in there, I thought..." — this rule was skipped.
