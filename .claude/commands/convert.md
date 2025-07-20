---
description: Convert
tools: "WebFetch(domain:cc.sj-cdn.net)",
---

## Your task

There are two string below. The first is a path to use for the Ruby output. The second is a URI to fetch:

$ARGUMENTS

Steps:
- Read the Python Jupyter notebook at the given URI
- Convert the notebook to a SINGLE Ruby file.
- Commit this as "Initial conversion to Ruby"
- Use `bundle exec ruby -wc` to check if the Ruby file is valid.
- If there are syntax errors, stop and ask the user what to do.
- Run `standard --fix` to fix any style issues.
- Commit again if anything was fixed.
- Try run the Ruby code

## Notes

- Where the Python API uses string literals as values, the Ruby equivalent is normally a symbol.
- Any local variables at the top level will need to be converted to constants.
- Don't put any `#!/usr/bin/env ruby` at the top of the file.
