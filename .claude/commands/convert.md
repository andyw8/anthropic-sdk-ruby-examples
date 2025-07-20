---
description: Convert
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

- Read the Python Juypyter notebook at #$ARGUMENTS
- Convert the notebook to a single file Ruby file
- Commit this as "Initial conversion to Ruby"
- Use `ruby -wc` to check the syntax of the Ruby file.
- If there are syntax errors, stop and ask the user what to do.
- Run `standard --fix` to fix any style issues.
- Commit again if anything was fixed.
- Try run the Ruby code

## Notes

- Where the Python API uses string literals as values, the Ruby equivalent is normally a symbol.
- Any local variables at the top level will need to be converted to constants.
- Don't put any `#!/usr/bin/env ruby` at the top of the file.
